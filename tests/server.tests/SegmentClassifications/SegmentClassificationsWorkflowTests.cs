using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.SegmentClassifications;
using Server.Models.Workflow;
using Server.Tests.AutoAssociations;
using Server.Tests.Helpers;
using Server.Tests.OrgRReview;
using Server.Workflow;

namespace Server.Tests.SegmentClassifications;

public partial class SegmentClassificationsControllerTests
{
    [Theory]
    [InlineData(SegmentType.Ern, false, null)]
    [InlineData(SegmentType.FinancialDepartment, false, null)]
    [InlineData(SegmentType.Account, false, null)]
    [InlineData(SegmentType.Activity, false, null)]
    [InlineData(SegmentType.Purpose, false, null)]
    [InlineData(SegmentType.Fund, false, null)]
    [InlineData(SegmentType.Fund, true, "220")]
    public async Task Changed_classification_reopens_review_and_clears_the_build(
        SegmentType type, bool included, string? sfn)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification
        {
            SegmentType = type, Code = "TEST", IncludeInReport = true,
            Sfn = type == SegmentType.Fund ? "201" : null,
        });
        await db.SaveChangesAsync();
        var builder = new FakeAutoAssociationBuilder();
        var workflow = await CompleteClassificationWorkflowAsync(appDb, db, builder);
        var before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);

        var result = await CreateController(db, workflowService: workflow).UpdateClassification(
            new UpdateClassificationRequest(type.ToString(), "TEST", included, sfn), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var saved = await db.SegmentClassifications.AsNoTracking().SingleAsync();
        saved.IncludeInReport.Should().Be(included);
        saved.Sfn.Should().Be(sfn);
        builder.Clears.Should().Be(1);
        AssertClassificationReopened(before, await workflow.GetSnapshotAsync(TestUser, CancellationToken.None));
    }

    [Theory]
    [InlineData(SegmentType.Ern, true, null, null)]
    [InlineData(SegmentType.Account, false, null, null)]
    [InlineData(SegmentType.Fund, true, "201", "201")]
    [InlineData(SegmentType.Fund, false, null, "201")]
    public async Task Unchanged_effective_classification_preserves_workflow_and_build(
        SegmentType type, bool included, string? storedSfn, string? requestedSfn)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification
        {
            SegmentType = type, Code = "TEST", IncludeInReport = included, Sfn = storedSfn,
        });
        await db.SaveChangesAsync();
        var builder = new FakeAutoAssociationBuilder();
        var workflow = await CompleteClassificationWorkflowAsync(appDb, db, builder);
        var before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();

        var result = await CreateController(db, invalidator, workflow).UpdateClassification(
            new UpdateClassificationRequest(type.ToString(), "TEST", included, requestedSfn), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        builder.Clears.Should().Be(0);
        invalidator.Calls.Should().Be(0);
        (await db.SegmentClassifications.AsNoTracking().SingleAsync()).Sfn.Should().Be(storedSfn);
        (await workflow.GetSnapshotAsync(TestUser, CancellationToken.None)).Should().BeEquivalentTo(before);
    }

    [Theory]
    [InlineData("Unknown", "TEST", null)]
    [InlineData("Fund", "MISSING", "201")]
    [InlineData("Fund", "TEST", "999")]
    [InlineData("Account", "TEST", "201")]
    public async Task Invalid_or_missing_classification_preserves_workflow_and_build(
        string type, string code, string? sfn)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.AddRange(
            new SegmentClassification { SegmentType = SegmentType.Fund, Code = "TEST", IncludeInReport = true, Sfn = "201" },
            new SegmentClassification { SegmentType = SegmentType.Account, Code = "TEST", IncludeInReport = true });
        await db.SaveChangesAsync();
        var original = await db.SegmentClassifications.AsNoTracking().ToListAsync();
        var builder = new FakeAutoAssociationBuilder();
        var workflow = await CompleteClassificationWorkflowAsync(appDb, db, builder);
        var before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);

        var result = await CreateController(db, workflowService: workflow).UpdateClassification(
            new UpdateClassificationRequest(type, code, true, sfn), CancellationToken.None);

        if (code == "MISSING") result.Should().BeOfType<NotFoundResult>();
        else result.Should().BeOfType<BadRequestObjectResult>();
        builder.Clears.Should().Be(0);
        (await db.SegmentClassifications.AsNoTracking().ToListAsync()).Should().BeEquivalentTo(original);
        (await workflow.GetSnapshotAsync(TestUser, CancellationToken.None)).Should().BeEquivalentTo(before);
    }

    [Theory]
    [InlineData(SegmentType.Ern, "workflow-reset")]
    [InlineData(SegmentType.Ern, "cancelled-reset")]
    [InlineData(SegmentType.Ern, "classification-save")]
    [InlineData(SegmentType.Account, "workflow-reset")]
    [InlineData(SegmentType.Account, "cancelled-reset")]
    [InlineData(SegmentType.Account, "classification-save")]
    public async Task Failed_classification_change_preserves_values_and_can_be_retried(SegmentType type, string failure)
    {
        // Fresh contexts share stores so assertions observe persisted state, not failed tracked changes.
        var appOptions = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"ClassificationApp_{Guid.NewGuid():N}", new InMemoryDatabaseRoot()).Options;
        var dataOptions = new DbContextOptionsBuilder<DataDbContext>()
            .UseInMemoryDatabase($"ClassificationData_{Guid.NewGuid():N}", new InMemoryDatabaseRoot()).Options;
        var builder = new FakeAutoAssociationBuilder();
        WorkflowSnapshotResponse before;
        using (var setupApp = new AppDbContext(appOptions))
        using (var setupData = new DataDbContext(dataOptions))
        {
            setupData.SegmentClassifications.Add(new SegmentClassification
            {
                SegmentType = type, Code = "TEST", IncludeInReport = true,
            });
            await setupData.SaveChangesAsync();
            var workflow = await CompleteClassificationWorkflowAsync(setupApp, setupData, builder);
            before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        }

        using var cancellation = new CancellationTokenSource();
        var interceptor = new FailClassificationSaveOnceInterceptor(token =>
        {
            if (failure == "cancelled-reset")
            {
                token.Should().Be(cancellation.Token);
                cancellation.Cancel();
                token.ThrowIfCancellationRequested();
            }
            throw new DbUpdateException("Injected classification save failure.");
        });
        var requestAppOptions = new DbContextOptionsBuilder<AppDbContext>(appOptions);
        var requestDataOptions = new DbContextOptionsBuilder<DataDbContext>(dataOptions);
        if (failure == "classification-save") requestDataOptions.AddInterceptors(interceptor);
        else requestAppOptions.AddInterceptors(interceptor);

        using (var requestApp = new AppDbContext(requestAppOptions.Options))
        using (var requestData = new DataDbContext(requestDataOptions.Options))
        {
            var workflow = new WorkflowService(requestApp, requestData, new FakeOrgRReviewSeeder(), builder);
            var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
            var controller = CreateController(requestData, invalidator, workflow);
            Func<Task> update = () => controller.UpdateClassification(
                new UpdateClassificationRequest(type.ToString(), "TEST", false, null), cancellation.Token);

            if (failure == "cancelled-reset") await update.Should().ThrowAsync<OperationCanceledException>();
            else await update.Should().ThrowAsync<DbUpdateException>().WithMessage("Injected classification save failure.");
            interceptor.HasFailed.Should().BeTrue();
            invalidator.Calls.Should().Be(0);
            if (failure != "classification-save")
            {
                requestData.ChangeTracker.HasChanges().Should().BeFalse("reset must finish before changing classification");
            }
        }

        // Clearing precedes the app workflow save, so even a failed reset may have cleared the build.
        builder.Clears.Should().Be(1);
        using (var verificationApp = new AppDbContext(appOptions))
        using (var verificationData = new DataDbContext(dataOptions))
        {
            (await verificationData.SegmentClassifications.SingleAsync()).IncludeInReport.Should().BeTrue();
            var workflow = new WorkflowService(verificationApp, verificationData, new FakeOrgRReviewSeeder(), builder);
            var afterFailure = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
            if (failure == "classification-save") AssertClassificationReopened(before, afterFailure);
            else afterFailure.Should().BeEquivalentTo(before);
        }

        using (var retryApp = new AppDbContext(appOptions))
        using (var retryData = new DataDbContext(dataOptions))
        {
            var workflow = new WorkflowService(retryApp, retryData, new FakeOrgRReviewSeeder(), builder);
            var result = await CreateController(retryData, workflowService: workflow).UpdateClassification(
                new UpdateClassificationRequest(type.ToString(), "TEST", false, null), CancellationToken.None);
            result.Should().BeOfType<NoContentResult>();
        }

        builder.Clears.Should().Be(2);
        using (var verificationApp = new AppDbContext(appOptions))
        using (var verificationData = new DataDbContext(dataOptions))
        {
            (await verificationData.SegmentClassifications.SingleAsync()).IncludeInReport.Should().BeFalse();
            var workflow = new WorkflowService(verificationApp, verificationData, new FakeOrgRReviewSeeder(), builder);
            AssertClassificationReopened(before, await workflow.GetSnapshotAsync(TestUser, CancellationToken.None));
        }
    }

    private static async Task<WorkflowService> CompleteClassificationWorkflowAsync(
        AppDbContext workflowDb, DataDbContext dataDb, FakeAutoAssociationBuilder builder)
    {
        var workflow = new WorkflowService(workflowDb, dataDb, new FakeOrgRReviewSeeder(), builder);
        foreach (var stage in WorkflowStages.All.Where(stage => stage.IsRequired))
        {
            var result = await workflow.SetStageStatusAsync(stage.Id, WorkflowStageStatus.Complete, TestUser, CancellationToken.None);
            result.Should().NotBeNull($"stage {stage.Id} should complete");
        }
        builder.Builds.Should().ContainSingle();
        builder.Clears.Should().Be(0);
        return workflow;
    }

    private static void AssertClassificationReopened(WorkflowSnapshotResponse before, WorkflowSnapshotResponse after)
    {
        var review = after.Stages.Single(stage => stage.Id == WorkflowStageIds.DataClassification);
        review.Status.Should().Be(WorkflowStageStatus.InProgress);
        review.CompletedAt.Should().BeNull();
        review.CompletedByName.Should().BeNull();
        review.CompletedByEmail.Should().BeNull();
        after.CurrentStageId.Should().Be(WorkflowStageIds.DataClassification);
        after.Stages.Where(stage => stage.Number < review.Number)
            .Should().BeEquivalentTo(before.Stages.Where(stage => stage.Number < review.Number));
        after.Stages.Where(stage => stage.Number > review.Number).Should().OnlyContain(stage =>
            stage.Status == WorkflowStageStatus.NotStarted && !stage.CanAccess
            && stage.CompletedAt == null && stage.CompletedByName == null && stage.CompletedByEmail == null);
    }

    private sealed class FailClassificationSaveOnceInterceptor(Action<CancellationToken> fail) : SaveChangesInterceptor
    {
        public bool HasFailed { get; private set; }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (!HasFailed)
            {
                HasFailed = true;
                fail(cancellationToken);
            }
            return ValueTask.FromResult(result);
        }
    }
}
