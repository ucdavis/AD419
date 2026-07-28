using System.Security.Claims;
using FluentAssertions;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Import;
using Server.Models;
using Server.Models.ProjectList;
using Server.ProjectIdentification;
using Server.ProjectList;

namespace Server.Tests.ProjectIdentification;

public class ProjectIdentificationServiceTests
{
    private static readonly ClaimsPrincipal User = new(new ClaimsIdentity(
        [
            new Claim("oid", "11111111-1111-1111-1111-111111111111"),
            new Claim("name", "Shannon Taylor"),
            new Claim("preferred_username", "shannon@example.edu"),
        ],
        "Test"));

    [Fact]
    public async Task Setup_creates_a_current_workflow_run_with_fiscal_period_active()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);

        var setup = await service.GetSetupAsync(User, CancellationToken.None);

        setup.WorkflowRunId.Should().BePositive();
        setup.TotalCount.Should().Be(7);
        setup.CompletedCount.Should().Be(0);
        setup.ChecklistItems[0].Id.Should().Be("fiscal-period");
        setup.ChecklistItems[0].Status.Should().Be("active");
        setup.ChecklistItems[1].Status.Should().Be("locked");
        db.WorkflowRuns.Should().ContainSingle(run => run.IsCurrent);
    }

    [Fact]
    public async Task ConfirmFiscalPeriod_completes_the_first_item()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);

        var setup = await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);

        setup.Should().NotBeNull();
        setup!.FiscalYear.Should().Be("FY26");
        setup.CycleStart.Should().Be(new DateOnly(2025, 10, 1));
        setup.CycleEnd.Should().Be(new DateOnly(2026, 9, 30));
        setup.CompletedCount.Should().Be(1);
        setup.ChecklistItems[0].Status.Should().Be("done");
        setup.ChecklistItems[1].Status.Should().Be("active");
    }

    [Fact]
    public async Task Import_items_require_previous_completion_and_successful_latest_import()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        AddImport(db, "all-projects", 1, "Succeeded", 100, DateTimeOffset.Parse("2026-06-01T12:00:00Z"));
        await db.SaveChangesAsync();

        var blocked = await service.SetChecklistItemCompletionAsync("all-projects", true, User, CancellationToken.None);
        blocked.Should().BeNull();

        await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);
        var setup = await service.SetChecklistItemCompletionAsync("all-projects", true, User, CancellationToken.None);

        setup.Should().NotBeNull();
        var allProjects = setup!.ChecklistItems.Single(item => item.Id == "all-projects");
        allProjects.Status.Should().Be("done");
        allProjects.Source!.ImportLogId.Should().Be(1);
        setup.ChecklistItems.Single(item => item.Id == "active-projects").Status.Should().Be("active");
    }

    [Fact]
    public async Task Newer_import_attempt_makes_prior_completion_stale()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        AddImport(db, "all-projects", 1, "Succeeded", 100, DateTimeOffset.Parse("2026-06-01T12:00:00Z"));
        await db.SaveChangesAsync();
        await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("all-projects", true, User, CancellationToken.None);

        AddImport(db, "all-projects", 2, "Succeeded", 110, DateTimeOffset.Parse("2026-06-02T12:00:00Z"));
        await db.SaveChangesAsync();

        var setup = await service.GetSetupAsync(User, CancellationToken.None);

        var allProjects = setup.ChecklistItems.Single(item => item.Id == "all-projects");
        allProjects.Completed.Should().BeFalse();
        allProjects.Stale.Should().BeTrue();
        allProjects.Status.Should().Be("stale");
        allProjects.StaleReason.Should().Contain("newer import");
    }

    [Fact]
    public async Task Pgm_import_result_makes_pgm_item_ready_but_not_complete()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);

        AddImport(db, "all-projects", 1, "Succeeded", 100, DateTimeOffset.Parse("2026-06-01T12:00:00Z"));
        AddImport(db, "active-projects", 2, "Succeeded", 50, DateTimeOffset.Parse("2026-06-01T12:01:00Z"));
        AddImport(db, "assistance-listing-numbers", 3, "Succeeded", 200, DateTimeOffset.Parse("2026-06-01T12:02:00Z"));
        await db.SaveChangesAsync();

        await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("all-projects", true, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("active-projects", true, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("assistance-listing-numbers", true, User, CancellationToken.None);
        await service.RecordPgmImportAsync(
            new PgmProjectsImportResult(1234, new DateOnly(2026, 9, 30)),
            User,
            CancellationToken.None);

        var setup = await service.GetSetupAsync(User, CancellationToken.None);

        var pgm = setup.ChecklistItems.Single(item => item.Id == "pgm-master-data");
        pgm.Ready.Should().BeTrue();
        pgm.Completed.Should().BeFalse();
        pgm.Status.Should().Be("ready");
        pgm.Source!.Rows.Should().Be(1234);
    }

    [Fact]
    public async Task Resolve_issues_requires_current_project_list_to_have_no_issues()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var projectListService = new StubProjectListService { IssuesToResolve = 2 };
        var service = CreateService(db, projectListService);

        AddImport(db, "all-projects", 1, "Succeeded", 100, DateTimeOffset.Parse("2026-06-01T12:00:00Z"));
        AddImport(db, "active-projects", 2, "Succeeded", 50, DateTimeOffset.Parse("2026-06-01T12:01:00Z"));
        AddImport(db, "assistance-listing-numbers", 3, "Succeeded", 200, DateTimeOffset.Parse("2026-06-01T12:02:00Z"));
        await db.SaveChangesAsync();

        await service.ConfirmFiscalPeriodAsync("FY26", User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("all-projects", true, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("active-projects", true, User, CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("assistance-listing-numbers", true, User, CancellationToken.None);
        await service.RecordPgmImportAsync(
            new PgmProjectsImportResult(1234, new DateOnly(2026, 9, 30)),
            User,
            CancellationToken.None);
        await service.SetChecklistItemCompletionAsync("pgm-master-data", true, User, CancellationToken.None);

        var blocked = await service.SetChecklistItemCompletionAsync(
            "resolve-project-issues",
            true,
            User,
            CancellationToken.None);
        projectListService.IssuesToResolve = 0;
        var completed = await service.SetChecklistItemCompletionAsync(
            "resolve-project-issues",
            true,
            User,
            CancellationToken.None);

        blocked.Should().BeNull();
        completed.Should().NotBeNull();
        completed!.ChecklistItems.Single(item => item.Id == "resolve-project-issues")
            .Status.Should().Be("done");
    }

    private static ProjectIdentificationService CreateService(
        Server.Core.Data.AppDbContext db,
        StubProjectListService? projectListService = null) =>
        new(db, new FlatFileImportRegistry(), projectListService ?? new StubProjectListService());

    private static void AddImport(
        Server.Core.Data.AppDbContext db,
        string dataset,
        int id,
        string status,
        int rows,
        DateTimeOffset completedAt)
    {
        db.ImportLogs.Add(new ImportLog
        {
            Id = id,
            Dataset = dataset,
            Filename = $"{dataset}-{id}.csv",
            Status = status,
            AttemptedRows = rows,
            RowsImported = status == "Succeeded" ? rows : null,
            StartedAt = completedAt.AddMinutes(-1),
            CompletedAt = completedAt,
        });
    }

    private sealed class StubProjectListService : IProjectListService
    {
        public int IssuesToResolve { get; set; }

        public Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            Task.FromResult(new ProjectListResponse(
                cycle.FiscalYear,
                cycle.CycleStart,
                cycle.CycleEnd,
                new ProjectListCountsDto(IssuesToResolve, 0, IssuesToResolve),
                new ProjectListSummaryDto(0, 0, 0, 0, IssuesToResolve, []),
                []));
    }
}
