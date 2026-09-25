using System.Security.Claims;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;
using Server.Models;
using Server.Tests.AutoAssociations;
using Server.Tests.OrgRReview;
using Server.Workflow;

namespace Server.Tests.Workflow;

public class WorkflowServiceTests
{
    private static readonly ClaimsPrincipal User = new(new ClaimsIdentity(
        [
            new Claim("oid", "22222222-2222-2222-2222-222222222222"),
            new Claim("name", "Shannon Taylor"),
            new Claim("preferred_username", "shannon@example.edu"),
        ],
        "Test"));

    [Fact]
    public async Task Snapshot_lazily_creates_all_stage_states_and_starts_project_identification()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);

        snapshot.WorkflowRunId.Should().BePositive();
        snapshot.Stages.Should().HaveCount(10);
        snapshot.Stages.Select(stage => stage.Id).Should().Equal(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageIds.StationSpecialistImport,
            WorkflowStageIds.DataImport,
            WorkflowStageIds.DataClassification,
            WorkflowStageIds.ExpenseReview,
            WorkflowStageIds.OrgRReview,
            WorkflowStageIds.AutoAssociations,
            WorkflowStageIds.ManualAssociations,
            WorkflowStageIds.PostAssociationReview,
            WorkflowStageIds.FinalReports);
        snapshot.Stages.Select(stage => stage.Number).Should().Equal(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        snapshot.Stages[0].Status.Should().Be(WorkflowStageStatus.InProgress);
        snapshot.Stages[0].CanAccess.Should().BeTrue();
        snapshot.Stages[1].Status.Should().Be(WorkflowStageStatus.NotStarted);
        snapshot.Stages[1].CanAccess.Should().BeTrue();
        snapshot.Stages[1].IsRequired.Should().BeFalse();
        snapshot.Stages[2].CanAccess.Should().BeFalse();
        db.WorkflowStageStates.Should().HaveCount(10);
    }

    [Fact]
    public async Task Snapshot_adds_missing_stage_states_without_recreating_existing_states()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var startedAt = DateTimeOffset.Parse("2026-06-01T12:00:00Z");
        var originalStartedBy = Guid.Parse("33333333-3333-3333-3333-333333333333");
        var run = new WorkflowRun
        {
            FiscalYear = "FY26",
            CycleStart = new DateOnly(2025, 10, 1),
            CycleEnd = new DateOnly(2026, 9, 30),
            CreatedAt = startedAt,
            IsCurrent = true,
            UpdatedAt = startedAt,
            StageStates =
            {
                new WorkflowStageState
                {
                    StageId = WorkflowStageIds.ProjectIdentification,
                    Status = WorkflowStageStatus.InProgress,
                    StartedAt = startedAt,
                    StartedByEntraId = originalStartedBy,
                    StartedByName = "Original User",
                    StartedByEmail = "original@example.edu",
                },
            },
        };
        db.WorkflowRuns.Add(run);
        await db.SaveChangesAsync();
        var projectIdentificationStateId = run.StageStates.Single().Id;
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);

        snapshot.WorkflowRunId.Should().Be(run.Id);
        snapshot.Stages.Should().HaveCount(10);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        db.WorkflowStageStates.Should().HaveCount(10);
        db.WorkflowStageStates.Should().Contain(state =>
            state.StageId == WorkflowStageIds.ManualAssociations);
        db.WorkflowStageStates.Should().Contain(state =>
            state.StageId == WorkflowStageIds.StationSpecialistImport);
        db.WorkflowStageStates.Should().Contain(state =>
            state.StageId == WorkflowStageIds.OrgRReview);
        var projectIdentificationStates = await db.WorkflowStageStates
            .Where(state => state.StageId == WorkflowStageIds.ProjectIdentification)
            .ToListAsync();
        projectIdentificationStates.Should().ContainSingle();
        projectIdentificationStates[0].Id.Should().Be(projectIdentificationStateId);
        projectIdentificationStates[0].StartedAt.Should().Be(startedAt);
        projectIdentificationStates[0].StartedByEntraId.Should().Be(originalStartedBy);
        projectIdentificationStates[0].StartedByName.Should().Be("Original User");
        projectIdentificationStates[0].StartedByEmail.Should().Be("original@example.edu");
    }

    [Fact]
    public async Task Completing_stages_advances_current_stage_and_blocks_skipping_ahead()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await service.GetSnapshotAsync(User, CancellationToken.None);

        var blocked = await service.SetStageStatusAsync(
            WorkflowStageIds.DataImport,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        var advanced = await service.SetStageStatusAsync(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        blocked.Should().BeNull();
        advanced.Should().NotBeNull();
        advanced!.CurrentStageId.Should().Be(WorkflowStageIds.DataImport);
        advanced.Stages.Single(stage => stage.Id == WorkflowStageIds.ProjectIdentification)
            .Status.Should().Be(WorkflowStageStatus.Complete);
        advanced.Stages.Single(stage => stage.Id == WorkflowStageIds.DataImport)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
        advanced.Stages.Single(stage => stage.Id == WorkflowStageIds.DataClassification)
            .CanAccess.Should().BeFalse();
    }

    [Fact]
    public async Task Optional_station_specialist_import_never_blocks_or_accepts_status_changes()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());

        await CompleteStageAsync(service, WorkflowStageIds.ProjectIdentification);
        await CompleteStageAsync(service, WorkflowStageIds.DataImport);
        await CompleteStageAsync(service, WorkflowStageIds.DataClassification);
        await CompleteStageAsync(service, WorkflowStageIds.ExpenseReview);
        await CompleteStageAsync(service, WorkflowStageIds.OrgRReview);
        await CompleteStageAsync(service, WorkflowStageIds.AutoAssociations);
        var initial = await service.GetSnapshotAsync(User, CancellationToken.None);
        var optional = initial.Stages.Single(stage => stage.Id == WorkflowStageIds.StationSpecialistImport);

        optional.CanAccess.Should().BeTrue();
        optional.IsRequired.Should().BeFalse();
        optional.Status.Should().Be(WorkflowStageStatus.NotStarted);

        var rejected = await service.SetStageStatusAsync(
            WorkflowStageIds.StationSpecialistImport,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        rejected.Should().BeNull();

        var reset = () => service.ResetFromStageAsync(
            WorkflowStageIds.StationSpecialistImport,
            User,
            CancellationToken.None);
        await reset.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*optional*");

        await CompleteStageAsync(service, WorkflowStageIds.ManualAssociations);
        var finalReports = await CompleteStageAsync(service, WorkflowStageIds.PostAssociationReview);

        finalReports.CurrentStageId.Should().Be(WorkflowStageIds.FinalReports);
        finalReports.Stages.Single(stage => stage.Id == WorkflowStageIds.StationSpecialistImport)
            .Status.Should().Be(WorkflowStageStatus.NotStarted);
        finalReports.Stages.Single(stage => stage.Id == WorkflowStageIds.FinalReports)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
    }

    [Fact]
    public async Task Reopening_completed_stage_clears_downstream_stages()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await service.SetStageStatusAsync(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        await service.SetStageStatusAsync(
            WorkflowStageIds.DataImport,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        await service.SetStageStatusAsync(
            WorkflowStageIds.DataClassification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        var reopened = await service.SetStageStatusAsync(
            WorkflowStageIds.DataImport,
            WorkflowStageStatus.InProgress,
            User,
            CancellationToken.None);

        reopened.Should().NotBeNull();
        reopened!.CurrentStageId.Should().Be(WorkflowStageIds.DataImport);
        reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.ProjectIdentification)
            .Status.Should().Be(WorkflowStageStatus.Complete);
        reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.DataImport)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
        reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.DataClassification)
            .Status.Should().Be(WorkflowStageStatus.NotStarted);
        reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.ExpenseReview)
            .CanAccess.Should().BeFalse();
        reopened.Stages.Single(stage => stage.Id == WorkflowStageIds.StationSpecialistImport)
            .CanAccess.Should().BeTrue();

        var dataClassification = await db.WorkflowStageStates.SingleAsync(
            state => state.StageId == WorkflowStageIds.DataClassification);
        dataClassification.CompletedAt.Should().BeNull();
        dataClassification.StartedAt.Should().BeNull();
    }

    [Fact]
    public async Task Completing_data_classification_is_blocked_while_segments_remain_unclassified()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        dataDb.SegmentClassifications.Add(new SegmentClassification
        {
            Code = "70575",
            IncludeInReport = null,
            SegmentType = SegmentType.Fund,
        });
        await dataDb.SaveChangesAsync();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());

        await service.SetStageStatusAsync(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        await service.SetStageStatusAsync(
            WorkflowStageIds.DataImport,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        var blocked = await service.SetStageStatusAsync(
            WorkflowStageIds.DataClassification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        blocked.Should().BeNull();
        db.WorkflowStageStates.Single(state => state.StageId == WorkflowStageIds.DataClassification)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
    }

    [Fact]
    public async Task Repeating_in_progress_preserves_started_audit_and_clears_completion_and_downstream()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await service.GetSnapshotAsync(User, CancellationToken.None);
        var startedAt = DateTimeOffset.Parse("2026-06-01T12:00:00Z");
        var completedAt = DateTimeOffset.Parse("2026-06-02T12:00:00Z");
        var originalStartedBy = Guid.Parse("33333333-3333-3333-3333-333333333333");

        var projectIdentification = await db.WorkflowStageStates.SingleAsync(
            state => state.StageId == WorkflowStageIds.ProjectIdentification);
        projectIdentification.Status = WorkflowStageStatus.InProgress;
        projectIdentification.StartedAt = startedAt;
        projectIdentification.StartedByEntraId = originalStartedBy;
        projectIdentification.StartedByName = "Original User";
        projectIdentification.StartedByEmail = "original@example.edu";
        projectIdentification.CompletedAt = completedAt;
        projectIdentification.CompletedByEntraId = originalStartedBy;
        projectIdentification.CompletedByName = "Completing User";
        projectIdentification.CompletedByEmail = "complete@example.edu";

        var dataImport = await db.WorkflowStageStates.SingleAsync(
            state => state.StageId == WorkflowStageIds.DataImport);
        dataImport.Status = WorkflowStageStatus.Complete;
        dataImport.StartedAt = startedAt;
        dataImport.StartedByEntraId = originalStartedBy;
        dataImport.StartedByName = "Downstream Starter";
        dataImport.StartedByEmail = "downstream-starter@example.edu";
        dataImport.CompletedAt = completedAt;
        dataImport.CompletedByEntraId = originalStartedBy;
        dataImport.CompletedByName = "Downstream Completer";
        dataImport.CompletedByEmail = "downstream-completer@example.edu";
        await db.SaveChangesAsync();

        var updated = await service.SetStageStatusAsync(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageStatus.InProgress,
            User,
            CancellationToken.None);

        updated.Should().NotBeNull();
        projectIdentification.StartedAt.Should().Be(startedAt);
        projectIdentification.StartedByEntraId.Should().Be(originalStartedBy);
        projectIdentification.StartedByName.Should().Be("Original User");
        projectIdentification.StartedByEmail.Should().Be("original@example.edu");
        projectIdentification.CompletedAt.Should().BeNull();
        projectIdentification.CompletedByEntraId.Should().BeNull();
        projectIdentification.CompletedByName.Should().BeNull();
        projectIdentification.CompletedByEmail.Should().BeNull();
        dataImport.Status.Should().Be(WorkflowStageStatus.NotStarted);
        dataImport.StartedAt.Should().BeNull();
        dataImport.StartedByEntraId.Should().BeNull();
        dataImport.StartedByName.Should().BeNull();
        dataImport.StartedByEmail.Should().BeNull();
        dataImport.CompletedAt.Should().BeNull();
        dataImport.CompletedByEntraId.Should().BeNull();
        dataImport.CompletedByName.Should().BeNull();
        dataImport.CompletedByEmail.Should().BeNull();
    }

    [Fact]
    public async Task Reset_from_stage_keeps_previous_stages_and_clears_downstream()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await service.SetStageStatusAsync(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        await service.SetStageStatusAsync(
            WorkflowStageIds.DataImport,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);
        await service.SetStageStatusAsync(
            WorkflowStageIds.DataClassification,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        await service.ResetFromStageAsync(WorkflowStageIds.DataImport, User, CancellationToken.None);

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.DataImport);
        snapshot.Stages.Single(stage => stage.Id == WorkflowStageIds.ProjectIdentification)
            .Status.Should().Be(WorkflowStageStatus.Complete);
        snapshot.Stages.Single(stage => stage.Id == WorkflowStageIds.DataImport)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
        snapshot.Stages.Single(stage => stage.Id == WorkflowStageIds.DataClassification)
            .Status.Should().Be(WorkflowStageStatus.NotStarted);
    }

    private static async Task<Server.Models.Workflow.WorkflowSnapshotResponse> CompleteStageAsync(
        WorkflowService service,
        string stageId)
    {
        var snapshot = await service.SetStageStatusAsync(
            stageId,
            WorkflowStageStatus.Complete,
            User,
            CancellationToken.None);

        snapshot.Should().NotBeNull();
        return snapshot!;
    }

    [Fact]
    public async Task Stages_include_orgr_review_between_expense_review_and_auto_associations()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);

        snapshot.Stages.Select(stage => stage.Id).Should().ContainInOrder(
            WorkflowStageIds.ExpenseReview,
            WorkflowStageIds.OrgRReview,
            WorkflowStageIds.AutoAssociations);
        snapshot.Stages.Single(stage => stage.Id == WorkflowStageIds.OrgRReview).Number.Should().Be(6);
        snapshot.Stages.Single(stage => stage.Id == WorkflowStageIds.FinalReports).Number.Should().Be(10);
    }

    [Fact]
    public async Task Completing_expense_review_seeds_orgr_review_rows()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var seeder = new FakeOrgRReviewSeeder();
        var service = new WorkflowService(db, dataDb, seeder, new FakeAutoAssociationBuilder());
        await CompleteThrough(service, WorkflowStageIds.DataClassification);

        await service.SetStageStatusAsync(WorkflowStageIds.ExpenseReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        seeder.Calls.Should().Be(1);
    }

    [Fact]
    public async Task OrgR_review_cannot_complete_while_a_mapping_is_unset()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        dataDb.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "AARE001", IncludeInReport = true });
        dataDb.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = null });
        await dataDb.SaveChangesAsync();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var result = await service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        result.Should().BeNull();
    }

    [Fact]
    public async Task OrgR_review_ignores_unmapped_departments_not_in_this_cycle()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        // No SegmentClassifications row, so this department is not in the cycle.
        dataDb.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "9OLD001", OrgR = null });
        await dataDb.SaveChangesAsync();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var result = await service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        result.Should().NotBeNull();
    }

    [Fact]
    public async Task OrgR_review_ignores_unmapped_departments_excluded_from_the_report()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        // Seeded when included, then reclassified as excluded: no OrgR is needed.
        dataDb.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "EXCL001", IncludeInReport = false });
        dataDb.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "EXCL001", OrgR = null });
        await dataDb.SaveChangesAsync();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var result = await service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        result.Should().NotBeNull();
    }

    [Fact]
    public async Task OrgR_review_completes_when_every_mapping_is_set()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        dataDb.OrgRs.Add(new OrgR { Code = "AARE" });
        dataDb.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        dataDb.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        await dataDb.SaveChangesAsync();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var result = await service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        result.Should().NotBeNull();
        result!.Stages.Single(stage => stage.Id == WorkflowStageIds.OrgRReview).Status.Should().Be(WorkflowStageStatus.Complete);
        result.Stages.Single(stage => stage.Id == WorkflowStageIds.AutoAssociations).Status.Should().Be(WorkflowStageStatus.InProgress);
    }

    [Fact]
    public async Task Completing_orgr_review_builds_auto_associations_for_the_run_cycle()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var result = await service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        result.Should().NotBeNull();
        var run = await db.WorkflowRuns.SingleAsync();
        builder.Builds.Should().ContainSingle().Which.Should().Be(new FiscalYearCycle(run.FiscalYear, run.CycleStart, run.CycleEnd));
        builder.Clears.Should().Be(0);
    }

    [Fact]
    public async Task Failed_build_leaves_orgr_review_incomplete()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder { BuildFailure = new InvalidOperationException("boom") };
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        await CompleteThrough(service, WorkflowStageIds.ExpenseReview);

        var act = () => service.SetStageStatusAsync(WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, User, CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>().WithMessage("boom");
        // AsNoTracking reads what was saved; the tracked entity still holds the unsaved completion.
        var state = await db.WorkflowStageStates.AsNoTracking().SingleAsync(s => s.StageId == WorkflowStageIds.OrgRReview);
        state.Status.Should().NotBe(WorkflowStageStatus.Complete);
        state.CompletedAt.Should().BeNull();
    }

    [Theory]
    [InlineData(WorkflowStageIds.ExpenseReview)]
    [InlineData(WorkflowStageIds.OrgRReview)]
    [InlineData(WorkflowStageIds.DataImport)]
    public async Task Reopening_a_stage_at_or_before_orgr_review_clears_auto_associations(string stageId)
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        await CompleteThrough(service, WorkflowStageIds.OrgRReview);
        builder.Clears.Should().Be(0);

        await service.SetStageStatusAsync(stageId, WorkflowStageStatus.InProgress, User, CancellationToken.None);

        builder.Clears.Should().Be(1);
    }

    [Fact]
    public async Task Reopening_auto_associations_itself_does_not_clear_staging()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        await CompleteThrough(service, WorkflowStageIds.AutoAssociations);

        await service.SetStageStatusAsync(WorkflowStageIds.AutoAssociations, WorkflowStageStatus.InProgress, User, CancellationToken.None);

        builder.Clears.Should().Be(0);
    }

    [Fact]
    public async Task Resetting_from_orgr_review_clears_auto_associations()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        await using var dataDb = TestDbContextFactory.CreateDataInMemory();
        var builder = new FakeAutoAssociationBuilder();
        var service = new WorkflowService(db, dataDb, new FakeOrgRReviewSeeder(), builder);
        await CompleteThrough(service, WorkflowStageIds.OrgRReview);

        await service.ResetFromStageAsync(WorkflowStageIds.OrgRReview, User, CancellationToken.None);

        builder.Clears.Should().Be(1);
    }

    // Completes every required stage from Project Identification through `lastStageId` in order.
    private static async Task CompleteThrough(WorkflowService service, string lastStageId)
    {
        foreach (var stage in WorkflowStages.All.Where(stage => stage.IsRequired))
        {
            var result = await service.SetStageStatusAsync(stage.Id, WorkflowStageStatus.Complete, User, CancellationToken.None);
            result.Should().NotBeNull($"stage {stage.Id} should complete");
            if (stage.Id == lastStageId)
            {
                return;
            }
        }
    }
}
