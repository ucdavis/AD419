using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.AutoAssociations;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.AutoAssociations;

namespace Server.Tests.AutoAssociations;

public class AutoAssociationsControllerTests
{
    [Fact]
    public async Task Every_report_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new StubReportService();
        var controller = new AutoAssociationsController(service, new FakeAutoAssociationBuilder(), db);

        (await controller.Build(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule204(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule20x(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule220(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.ExcludedProjects(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.FteOverOne(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.PreAssociationTotals(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        service.Calls.Should().Be(0);
    }

    [Fact]
    public async Task Build_wraps_a_null_build_in_the_cycle_envelope()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "FY25",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        var service = new StubReportService();
        var controller = new AutoAssociationsController(service, new FakeAutoAssociationBuilder(), db);

        var result = await controller.Build(CancellationToken.None);

        var ok = result.Should().BeOfType<OkObjectResult>().Subject;
        var response = ok.Value.Should().BeOfType<AutoAssociationReportResponse<AutoAssociationBuildDto?>>().Subject;
        response.FiscalYear.Should().Be("FY25");
        response.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
        response.Data.Should().BeNull();
        service.Calls.Should().Be(1);
    }

    private static async Task<Server.Core.Data.AppDbContext> CreateDbWithRunAsync()
    {
        var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "FY25",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        return db;
    }

    private static readonly AutoAssociationBuildDto NewBuild = new(
        7, new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30), DateTimeOffset.UtcNow, 9, 11, 2, 0);

    [Fact]
    public async Task Rebuild_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var builder = new FakeAutoAssociationBuilder();
        var controller = new AutoAssociationsController(new StubReportService(), builder, db);

        var result = await controller.Rebuild(CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>()
            .Which.Value.Should().Be("No fiscal period has been confirmed in Project Identification.");
        builder.Builds.Should().BeEmpty();
    }

    [Fact]
    public async Task Rebuild_conflicts_when_no_build_exists()
    {
        await using var db = await CreateDbWithRunAsync();
        var builder = new FakeAutoAssociationBuilder { BuildExists = false };
        var controller = new AutoAssociationsController(new StubReportService(), builder, db);

        var result = await controller.Rebuild(CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>()
            .Which.Value.Should().Be("Auto-associations have not run yet.");
        builder.Builds.Should().BeEmpty();
    }

    [Fact]
    public async Task Rebuild_runs_the_build_for_the_current_cycle_and_returns_the_new_build()
    {
        await using var db = await CreateDbWithRunAsync();
        var builder = new FakeAutoAssociationBuilder();
        var service = new StubReportService { Build = NewBuild };
        var controller = new AutoAssociationsController(service, builder, db);

        var result = await controller.Rebuild(CancellationToken.None);

        builder.Builds.Should().Equal(new Server.Models.FiscalYearCycle("FY25", new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30)));
        var response = result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeOfType<AutoAssociationReportResponse<AutoAssociationBuildDto?>>().Subject;
        response.FiscalYear.Should().Be("FY25");
        response.Data.Should().Be(NewBuild);
        // Stage statuses are left alone.
        db.WorkflowStageStates.Should().BeEmpty();
    }

    [Fact]
    public async Task Rebuild_returns_conflict_with_the_procedure_message_when_the_build_is_rejected()
    {
        await using var db = await CreateDbWithRunAsync();
        const string message = "Projects is empty; run the Data Import before building auto-associations.";
        var builder = new FakeAutoAssociationBuilder
        {
            BuildFailure = new AutoAssociationBuildException(message, new InvalidOperationException("inner")),
        };
        var service = new StubReportService { Build = NewBuild };
        var controller = new AutoAssociationsController(service, builder, db);

        var result = await controller.Rebuild(CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>().Which.Value.Should().Be(message);
        // The old build is not read back as if it were new.
        service.Calls.Should().Be(0);
    }

    [Fact]
    public async Task Rebuild_lets_an_unexpected_failure_propagate()
    {
        await using var db = await CreateDbWithRunAsync();
        var builder = new FakeAutoAssociationBuilder { BuildFailure = new TimeoutException("too slow") };
        var controller = new AutoAssociationsController(new StubReportService(), builder, db);

        await FluentActions.Awaiting(() => controller.Rebuild(CancellationToken.None))
            .Should().ThrowAsync<TimeoutException>();
    }

    private sealed class StubReportService : IAutoAssociationReportService
    {
        public int Calls { get; private set; }

        public AutoAssociationBuildDto? Build { get; set; }

        public Task<AutoAssociationBuildDto?> GetBuildAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(Build);
        }

        public Task<Rule204ReportDto> GetRule204Async(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule204ReportDto([], [], []));
        }

        public Task<Rule20xReportDto> GetRule20xAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule20xReportDto([], []));
        }

        public Task<Rule220ReportDto> GetRule220Async(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule220ReportDto([], []));
        }

        public Task<IReadOnlyList<ExcludedProjectDto>> GetExcludedProjectsAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<ExcludedProjectDto>>([]);
        }

        public Task<IReadOnlyList<FteOverOneDto>> GetFteOverOneAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<FteOverOneDto>>([]);
        }

        public Task<IReadOnlyList<PreAssociationTotalDto>> GetPreAssociationTotalsAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<PreAssociationTotalDto>>([]);
        }
    }
}
