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
        snapshot.Stages.Select(stage => stage.Id).Should().Equal(
            WorkflowStageIds.ProjectIdentification,
            WorkflowStageIds.DataImport,
            WorkflowStageIds.DataClassification,
            WorkflowStageIds.ExpenseReview,
            WorkflowStageIds.AutoAssociations,
            WorkflowStageIds.PostAssociationReview,
            WorkflowStageIds.StationSpecialistImport,
            WorkflowStageIds.FinalReports);
        snapshot.CurrentStageId.Should().Be(WorkflowStageIds.ProjectIdentification);
        snapshot.Stages[0].Status.Should().Be(WorkflowStageStatus.InProgress);
        snapshot.Stages[0].CanAccess.Should().BeTrue();
        snapshot.Stages[1].Status.Should().Be(WorkflowStageStatus.NotStarted);
        snapshot.Stages[1].CanAccess.Should().BeFalse();
        db.WorkflowStageStates.Should().HaveCount(8);
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
    public async Task Completing_post_association_starts_station_specialist_import_before_final_reports()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new WorkflowService(db);

        await CompleteStageAsync(service, WorkflowStageIds.ProjectIdentification);
        await CompleteStageAsync(service, WorkflowStageIds.DataImport);
        await CompleteStageAsync(service, WorkflowStageIds.DataClassification);
        await CompleteStageAsync(service, WorkflowStageIds.ExpenseReview);
        await CompleteStageAsync(service, WorkflowStageIds.AutoAssociations);
        var stationSpecialist = await CompleteStageAsync(service, WorkflowStageIds.PostAssociationReview);

        stationSpecialist.CurrentStageId.Should().Be(WorkflowStageIds.StationSpecialistImport);
        stationSpecialist.Stages.Single(stage => stage.Id == WorkflowStageIds.StationSpecialistImport)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
        stationSpecialist.Stages.Single(stage => stage.Id == WorkflowStageIds.FinalReports)
            .CanAccess.Should().BeFalse();

        var finalReports = await CompleteStageAsync(service, WorkflowStageIds.StationSpecialistImport);

        finalReports.CurrentStageId.Should().Be(WorkflowStageIds.FinalReports);
        finalReports.Stages.Single(stage => stage.Id == WorkflowStageIds.StationSpecialistImport)
            .Status.Should().Be(WorkflowStageStatus.Complete);
        finalReports.Stages.Single(stage => stage.Id == WorkflowStageIds.FinalReports)
            .Status.Should().Be(WorkflowStageStatus.InProgress);
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
}
