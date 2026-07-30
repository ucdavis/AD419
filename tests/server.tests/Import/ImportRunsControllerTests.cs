using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Controllers;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Models.ImportRuns;
using System.Security.Claims;

namespace Server.Tests.Import;

public class ImportRunsControllerTests
{
    private sealed class FakeStageProvider : IImportStageProvider
    {
        public IReadOnlyList<string> StageNames => ImportStageNames.All;
        public IReadOnlyList<ImportStage> BuildStages(ImportRunContext context) =>
            StageNames.Select(name => new ImportStage(name, _ => Task.FromResult(0))).ToList();
    }

    private sealed class RecordingRunStarter : IImportRunStarter
    {
        public List<int> StartedRunIds { get; } = [];
        public void Start(int runId) => StartedRunIds.Add(runId);
    }

    private sealed class FakeReadinessCheck(string? blockingIssue) : IImportReadinessCheck
    {
        public Task<string?> GetBlockingIssueAsync(CancellationToken cancellationToken) =>
            Task.FromResult(blockingIssue);
    }

    private static ImportRunsController CreateController(
        AppDbContext db, RecordingRunStarter starter, string? blockingIssue = null)
    {
        var controller = new ImportRunsController(
            db, new FakeStageProvider(), starter, new FakeReadinessCheck(blockingIssue));
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(
                    [new Claim("name", "Rob Martinsen"), new Claim("preferred_username", "rob@ucdavis.edu")],
                    "test")),
            },
        };
        return controller;
    }

    [Fact]
    public async Task Start_creates_run_with_all_pending_stages_and_starts_it()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var starter = new RecordingRunStarter();
        var controller = CreateController(db, starter);

        var result = await controller.Start(
            new StartImportRunRequest(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30)),
            CancellationToken.None);

        var dto = result.Value!;
        dto.Status.Should().Be(ImportRunStatus.Running);
        dto.Stages.Should().HaveCount(13);
        dto.Stages.Should().OnlyContain(s => s.Status == ImportStageStatus.Pending);
        dto.Stages.Select(s => s.Name).Should().ContainInOrder(ImportStageNames.All);
        starter.StartedRunIds.Should().Equal(dto.Id);
        (await db.ImportRuns.Include(r => r.Stages).SingleAsync()).Stages.Should().HaveCount(13);
    }

    [Fact]
    public async Task Start_returns_409_when_a_run_is_already_running()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.ImportRuns.Add(new ImportRun
        {
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            Status = ImportRunStatus.Running,
            StartedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        var starter = new RecordingRunStarter();
        var controller = CreateController(db, starter);

        var result = await controller.Start(
            new StartImportRunRequest(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30)),
            CancellationToken.None);

        result.Result.Should().BeOfType<ConflictObjectResult>();
        starter.StartedRunIds.Should().BeEmpty();
    }

    [Fact]
    public async Task Start_returns_409_when_project_identification_is_not_ready()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var starter = new RecordingRunStarter();
        var controller = CreateController(
            db, starter, "Unresolved project issues exist; resolve them in Project Identification first.");

        var result = await controller.Start(
            new StartImportRunRequest(new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30)),
            CancellationToken.None);

        var conflict = result.Result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().Be("Unresolved project issues exist; resolve them in Project Identification first.");
        starter.StartedRunIds.Should().BeEmpty();
        (await db.ImportRuns.AnyAsync()).Should().BeFalse();
    }

    [Fact]
    public async Task Start_rejects_missing_or_reversed_dates()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var controller = CreateController(db, new RecordingRunStarter());

        (await controller.Start(new StartImportRunRequest(null, new DateOnly(2025, 9, 30)), CancellationToken.None))
            .Result.Should().BeOfType<BadRequestObjectResult>();
        (await controller.Start(new StartImportRunRequest(new DateOnly(2025, 9, 30), new DateOnly(2024, 10, 1)), CancellationToken.None))
            .Result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Current_returns_latest_run_or_204()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var controller = CreateController(db, new RecordingRunStarter());

        (await controller.Current(CancellationToken.None)).Result.Should().BeOfType<NoContentResult>();

        db.ImportRuns.AddRange(
            new ImportRun { CycleStart = new(2023, 10, 1), CycleEnd = new(2024, 9, 30), Status = ImportRunStatus.Succeeded, StartedAt = DateTimeOffset.UtcNow.AddDays(-2) },
            new ImportRun { CycleStart = new(2024, 10, 1), CycleEnd = new(2025, 9, 30), Status = ImportRunStatus.Failed, StartedAt = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync();

        var dto = (await controller.Current(CancellationToken.None)).Value!;
        dto.Status.Should().Be(ImportRunStatus.Failed);
        dto.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
    }
}
