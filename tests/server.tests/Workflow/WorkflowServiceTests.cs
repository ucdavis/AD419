using System.Security.Claims;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;
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
        var service = new WorkflowService(db);

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);

        snapshot.WorkflowRunId.Should().BePositive();
        snapshot.Stages.Should().HaveCount(8);
        snapshot.Stages.Select(stage => stage.Id).Should().ContainInOrder(
            WorkflowStageIds.AutoAssociations,
            WorkflowStageIds.ManualAssociations,
            WorkflowStageIds.PostAssociationReview);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        snapshot.Stages[0].Status.Should().Be(WorkflowStageStatus.InProgress);
        snapshot.Stages[0].CanAccess.Should().BeTrue();
        snapshot.Stages[1].Status.Should().Be(WorkflowStageStatus.NotStarted);
        snapshot.Stages[1].CanAccess.Should().BeFalse();
        db.WorkflowStageStates.Should().HaveCount(8);
    }

    [Fact]
    public async Task Snapshot_adds_missing_stage_states_without_recreating_existing_states()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
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
        var service = new WorkflowService(db);

        var snapshot = await service.GetSnapshotAsync(User, CancellationToken.None);

        snapshot.WorkflowRunId.Should().Be(run.Id);
        snapshot.Stages.Should().HaveCount(8);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        db.WorkflowStageStates.Should().HaveCount(8);
        db.WorkflowStageStates.Should().Contain(state =>
            state.StageId == WorkflowStageIds.ManualAssociations);
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
        var service = new WorkflowService(db);
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
    public async Task Reopening_completed_stage_clears_downstream_stages()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new WorkflowService(db);
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
        var service = new WorkflowService(db, dataDb);

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
        var service = new WorkflowService(db);
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
        var service = new WorkflowService(db);
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
}
