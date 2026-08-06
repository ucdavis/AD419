using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Core.Import;

namespace Server.Tests.Import;

public class ImportRunOrchestratorTests
{
    private sealed class FakeStageProvider(params ImportStage[] stages) : IImportStageProvider
    {
        public IReadOnlyList<string> StageNames { get; } = stages.Select(s => s.Name).ToList();
        public IReadOnlyList<ImportStage> BuildStages(ImportRunContext context) => stages;
    }

    private static async Task<int> SeedRunAsync(AppDbContext db, IImportStageProvider provider)
    {
        var run = new ImportRun
        {
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            Status = ImportRunStatus.Running,
            StartedAt = DateTimeOffset.UtcNow,
            Stages = provider.StageNames
                .Select((name, i) => new ImportRunStage { Name = name, Ordinal = i, Status = ImportStageStatus.Pending })
                .ToList(),
        };
        db.ImportRuns.Add(run);
        await db.SaveChangesAsync();
        return run.Id;
    }

    [Fact]
    public async Task Runs_stages_in_order_and_records_row_counts()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var order = new List<string>();
        var provider = new FakeStageProvider(
            ImportStage.FromRowCount("one", _ => { order.Add("one"); return Task.FromResult(5); }),
            new ImportStage("two", _ =>
            {
                order.Add("two");
                return Task.FromResult(new ImportStageResult(7, "7 AE projects, 3 NIFA projects"));
            }));
        var runId = await SeedRunAsync(db, provider);

        await new ImportRunOrchestrator(db, provider, NullLogger<ImportRunOrchestrator>.Instance).RunAsync(runId);

        order.Should().Equal("one", "two");
        var run = await db.ImportRuns.Include(r => r.Stages).SingleAsync();
        run.Status.Should().Be(ImportRunStatus.Succeeded);
        run.CompletedAt.Should().NotBeNull();
        run.Stages.Should().OnlyContain(s => s.Status == ImportStageStatus.Succeeded);
        run.Stages.Single(s => s.Name == "one").RowCount.Should().Be(5);
        run.Stages.Single(s => s.Name == "one").Detail.Should().BeNull();
        run.Stages.Single(s => s.Name == "two").RowCount.Should().Be(7);
        run.Stages.Single(s => s.Name == "two").Detail.Should().Be("7 AE projects, 3 NIFA projects");
    }

    [Fact]
    public async Task Failing_stage_stops_the_run_and_leaves_later_stages_pending()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var provider = new FakeStageProvider(
            ImportStage.FromRowCount("one", _ => Task.FromResult(1)),
            ImportStage.FromRowCount("boom", _ => throw new InvalidOperationException("warehouse offline")),
            ImportStage.FromRowCount("three", _ => Task.FromResult(3)));
        var runId = await SeedRunAsync(db, provider);

        await new ImportRunOrchestrator(db, provider, NullLogger<ImportRunOrchestrator>.Instance).RunAsync(runId);

        var run = await db.ImportRuns.Include(r => r.Stages).SingleAsync();
        run.Status.Should().Be(ImportRunStatus.Failed);
        run.Stages.Single(s => s.Name == "one").Status.Should().Be(ImportStageStatus.Succeeded);
        var failed = run.Stages.Single(s => s.Name == "boom");
        failed.Status.Should().Be(ImportStageStatus.Failed);
        failed.ErrorDetail.Should().Contain("warehouse offline");
        run.Stages.Single(s => s.Name == "three").Status.Should().Be(ImportStageStatus.Pending);
    }

    [Fact]
    public async Task Startup_sweep_marks_running_runs_failed()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.ImportRuns.Add(new ImportRun
        {
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            Status = ImportRunStatus.Running,
            StartedAt = DateTimeOffset.UtcNow,
            Stages =
            {
                new ImportRunStage { Name = "one", Ordinal = 0, Status = ImportStageStatus.Succeeded },
                new ImportRunStage { Name = "two", Ordinal = 1, Status = ImportStageStatus.Running },
                new ImportRunStage { Name = "three", Ordinal = 2, Status = ImportStageStatus.Pending },
            },
        });
        await db.SaveChangesAsync();

        await ImportRunOrchestrator.FailInterruptedRunsAsync(db);

        var run = await db.ImportRuns.Include(r => r.Stages).SingleAsync();
        run.Status.Should().Be(ImportRunStatus.Failed);
        run.Stages.Single(s => s.Name == "two").Status.Should().Be(ImportStageStatus.Failed);
        run.Stages.Single(s => s.Name == "two").ErrorDetail.Should().Be("Interrupted by application restart.");
        run.Stages.Single(s => s.Name == "one").Status.Should().Be(ImportStageStatus.Succeeded);
        run.Stages.Single(s => s.Name == "three").Status.Should().Be(ImportStageStatus.Pending);
    }
}
