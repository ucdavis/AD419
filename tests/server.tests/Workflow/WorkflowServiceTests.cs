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
        snapshot.Stages.Should().HaveCount(7);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        snapshot.Stages[0].Status.Should().Be(WorkflowStageStatus.InProgress);
        snapshot.Stages[0].CanAccess.Should().BeTrue();
        snapshot.Stages[1].Status.Should().Be(WorkflowStageStatus.NotStarted);
        snapshot.Stages[1].CanAccess.Should().BeFalse();
        db.WorkflowStageStates.Should().HaveCount(7);
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
