using System.Security.Claims;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Server.Controllers;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.OrgR;
using Server.Models.SegmentClassifications;
using Server.Models.Workflow;
using Server.Tests.AutoAssociations;
using Server.Workflow;

namespace Server.Tests.OrgRReview;

public class OrgRControllerTests : IDisposable
{
    private readonly AppDbContext appDb = TestDbContextFactory.CreateInMemory();
    private static readonly ClaimsPrincipal TestUser = new(new ClaimsIdentity(
        [new Claim("name", "OrgR Reviewer")], "Test"));

    public void Dispose() => appDb.Dispose();

    private OrgRController CreateController(
        DataDbContext db,
        FakeOrgRReviewSeeder? seeder = null,
        IWorkflowService? workflowService = null) =>
        new(db, seeder ?? new FakeOrgRReviewSeeder(), workflowService ?? new WorkflowService(appDb, db, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder()))
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = TestUser },
            },
        };

    private async Task<WorkflowService> CompleteWorkflowAsync(DataDbContext db, AppDbContext? workflowDb = null)
    {
        db.OrgRs.AddRange(new OrgR { Code = "AARE" }, new OrgR { Code = "APLS" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        db.SegmentClassifications.Add(new SegmentClassification
        {
            SegmentType = SegmentType.FinancialDepartment, Code = "AARE001", IncludeInReport = true,
        });
        await db.SaveChangesAsync();
        var workflow = new WorkflowService(workflowDb ?? appDb, db, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
        foreach (var stage in WorkflowStages.All.Where(stage => stage.IsRequired))
        {
            var result = await workflow.SetStageStatusAsync(stage.Id, WorkflowStageStatus.Complete, TestUser, CancellationToken.None);
            result.Should().NotBeNull($"stage {stage.Id} should complete");
        }
        return workflow;
    }

    [Theory]
    [InlineData(true, null)]
    [InlineData(false, null)]
    [InlineData(true, "APLS")]
    [InlineData(false, "APLS")]
    public Task Failed_reset_preserves_mapping_and_allows_retry(bool financial, string? orgR) =>
        AssertFailedUpdateCanBeRetriedAsync(financial, orgR, SaveFailure.WorkflowReset);

    [Theory]
    [InlineData(true, null)]
    [InlineData(false, null)]
    [InlineData(true, "APLS")]
    [InlineData(false, "APLS")]
    public Task Failed_mapping_save_leaves_review_reopened_and_allows_retry(bool financial, string? orgR) =>
        AssertFailedUpdateCanBeRetriedAsync(financial, orgR, SaveFailure.MappingSave);

    [Theory]
    [InlineData(true, null)]
    [InlineData(false, null)]
    [InlineData(true, "APLS")]
    [InlineData(false, "APLS")]
    public Task Cancelled_reset_preserves_mapping_and_allows_retry(bool financial, string? orgR) =>
        AssertFailedUpdateCanBeRetriedAsync(financial, orgR, SaveFailure.CancelledReset);

    private async Task AssertFailedUpdateCanBeRetriedAsync(bool financial, string? orgR, SaveFailure failure)
    {
        // Explicit roots keep fresh contexts on the same stores, including contexts with interceptors.
        var appOptions = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase($"OrgRApp_{Guid.NewGuid():N}", new InMemoryDatabaseRoot()).Options;
        var dataOptions = new DbContextOptionsBuilder<DataDbContext>()
            .UseInMemoryDatabase($"OrgRData_{Guid.NewGuid():N}", new InMemoryDatabaseRoot()).Options;
        WorkflowSnapshotResponse before;
        using (var setupApp = new AppDbContext(appOptions))
        using (var setupData = new DataDbContext(dataOptions))
        {
            var workflow = await CompleteWorkflowAsync(setupData, setupApp);
            before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        }

        using var cancellation = new CancellationTokenSource();
        var interceptor = new FailSaveOnceInterceptor(token =>
        {
            if (failure == SaveFailure.CancelledReset)
            {
                token.Should().Be(cancellation.Token);
                cancellation.Cancel();
                token.ThrowIfCancellationRequested();
            }

            throw new DbUpdateException("Injected save failure.");
        });
        var requestAppOptions = new DbContextOptionsBuilder<AppDbContext>(appOptions);
        var requestDataOptions = new DbContextOptionsBuilder<DataDbContext>(dataOptions);
        if (failure == SaveFailure.MappingSave)
        {
            requestDataOptions.AddInterceptors(interceptor);
        }
        else
        {
            requestAppOptions.AddInterceptors(interceptor);
        }

        using (var requestApp = new AppDbContext(requestAppOptions.Options))
        using (var requestData = new DataDbContext(requestDataOptions.Options))
        {
            var controller = CreateController(requestData, workflowService:
                new WorkflowService(requestApp, requestData, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder()));
            Func<Task> update = () => SetMappingAsync(controller, financial, orgR, cancellation.Token);
            if (failure == SaveFailure.CancelledReset)
            {
                await update.Should().ThrowAsync<OperationCanceledException>();
            }
            else
            {
                await update.Should().ThrowAsync<DbUpdateException>().WithMessage("Injected save failure.");
            }
            interceptor.HasFailed.Should().BeTrue();
        }

        using (var verificationApp = new AppDbContext(appOptions))
        using (var verificationData = new DataDbContext(dataOptions))
        {
            (await ReadMappingAsync(verificationData, financial)).Should().Be("AARE");
            var workflow = new WorkflowService(verificationApp, verificationData, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
            var afterFailure = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
            if (failure == SaveFailure.MappingSave)
            {
                AssertReviewReopened(before, afterFailure);
            }
            else
            {
                afterFailure.Should().BeEquivalentTo(before);
            }
        }

        using (var retryApp = new AppDbContext(appOptions))
        using (var retryData = new DataDbContext(dataOptions))
        {
            var controller = CreateController(retryData, workflowService:
                new WorkflowService(retryApp, retryData, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder()));
            (await SetMappingAsync(controller, financial, orgR, CancellationToken.None))
                .Should().BeOfType<NoContentResult>();
        }

        using (var verificationApp = new AppDbContext(appOptions))
        using (var verificationData = new DataDbContext(dataOptions))
        {
            (await ReadMappingAsync(verificationData, financial)).Should().Be(orgR);
            var workflow = new WorkflowService(verificationApp, verificationData, new FakeOrgRReviewSeeder(), new FakeAutoAssociationBuilder());
            AssertReviewReopened(before, await workflow.GetSnapshotAsync(TestUser, CancellationToken.None));
        }
    }

    private static Task<IActionResult> SetMappingAsync(
        OrgRController controller, bool financial, string? orgR, CancellationToken cancellationToken) =>
        financial
            ? controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest(orgR), cancellationToken)
            : controller.SetNifaDepartmentOrgR("ARE", new SetOrgRRequest(orgR), cancellationToken);

    private static async Task<string?> ReadMappingAsync(DataDbContext db, bool financial) =>
        financial
            ? (await db.OrgRFinancialDepartments.SingleAsync()).OrgR
            : (await db.OrgRNifaDepartments.SingleAsync()).OrgR;

    private static void AssertReviewReopened(WorkflowSnapshotResponse before, WorkflowSnapshotResponse after)
    {
        var review = after.Stages.Single(stage => stage.Id == WorkflowStageIds.OrgRReview);
        review.Status.Should().Be(WorkflowStageStatus.InProgress);
        review.CompletedAt.Should().BeNull();
        review.CompletedByName.Should().BeNull();
        review.CompletedByEmail.Should().BeNull();
        after.CurrentStageId.Should().Be(WorkflowStageIds.OrgRReview);
        after.Stages.Where(stage => stage.Number < review.Number)
            .Should().BeEquivalentTo(before.Stages.Where(stage => stage.Number < review.Number));
        after.Stages.Where(stage => stage.Number > review.Number).Should().OnlyContain(stage =>
            stage.Status == WorkflowStageStatus.NotStarted && !stage.CanAccess
            && stage.CompletedAt == null && stage.CompletedByName == null && stage.CompletedByEmail == null);
    }

    private enum SaveFailure { WorkflowReset, MappingSave, CancelledReset }

    private sealed class FailSaveOnceInterceptor(Action<CancellationToken> fail) : SaveChangesInterceptor
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

    [Theory]
    [InlineData(true, null)]
    [InlineData(false, null)]
    [InlineData(true, "APLS")]
    [InlineData(false, "APLS")]
    public async Task Changing_department_mapping_reopens_review_and_clears_downstream(bool financial, string? orgR)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var workflow = await CompleteWorkflowAsync(db);
        var before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        var controller = CreateController(db);

        var result = financial
            ? await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest(orgR), CancellationToken.None)
            : await controller.SetNifaDepartmentOrgR("ARE", new SetOrgRRequest(orgR), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        (financial ? db.OrgRFinancialDepartments.Single().OrgR : db.OrgRNifaDepartments.Single().OrgR)
            .Should().Be(orgR);
        var after = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        var review = after.Stages.Single(stage => stage.Id == WorkflowStageIds.OrgRReview);
        review.Status.Should().Be(WorkflowStageStatus.InProgress);
        review.CompletedAt.Should().BeNull();
        review.CompletedByName.Should().BeNull();
        after.CurrentStageId.Should().Be(WorkflowStageIds.OrgRReview);
        after.Stages.Where(stage => stage.Number < review.Number)
            .Should().BeEquivalentTo(before.Stages.Where(stage => stage.Number < review.Number));
        after.Stages.Where(stage => stage.Number > review.Number).Should().OnlyContain(stage =>
            stage.Status == WorkflowStageStatus.NotStarted && !stage.CanAccess
            && stage.CompletedAt == null && stage.CompletedByName == null && stage.CompletedByEmail == null);

        var completed = await workflow.SetStageStatusAsync(
            WorkflowStageIds.OrgRReview, WorkflowStageStatus.Complete, TestUser, CancellationToken.None);
        if (orgR == null)
        {
            completed.Should().BeNull();
        }
        else
        {
            completed.Should().NotBeNull();
        }
    }

    [Theory]
    [InlineData(true, " aare ", false)]
    [InlineData(false, " aare ", false)]
    [InlineData(true, "UNKNOWN", false)]
    [InlineData(false, "UNKNOWN", false)]
    [InlineData(true, "AARE", true)]
    [InlineData(false, "AARE", true)]
    public async Task Unchanged_or_invalid_mapping_preserves_completed_workflow(bool financial, string orgR, bool unknownDepartment)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var workflow = await CompleteWorkflowAsync(db);
        var before = await workflow.GetSnapshotAsync(TestUser, CancellationToken.None);
        var controller = CreateController(db);
        var code = unknownDepartment ? "MISSING" : financial ? "AARE001" : "ARE";

        var result = financial
            ? await controller.SetFinancialDepartmentOrgR(code, new SetOrgRRequest(orgR), CancellationToken.None)
            : await controller.SetNifaDepartmentOrgR(code, new SetOrgRRequest(orgR), CancellationToken.None);

        if (unknownDepartment)
        {
            result.Should().BeOfType<NotFoundResult>();
        }
        else if (orgR == "UNKNOWN")
        {
            result.Should().BeOfType<BadRequestObjectResult>();
        }
        else
        {
            result.Should().BeOfType<NoContentResult>();
        }
        db.OrgRFinancialDepartments.Single().OrgR.Should().Be("AARE");
        db.OrgRNifaDepartments.Single().OrgR.Should().Be("AARE");
        (await workflow.GetSnapshotAsync(TestUser, CancellationToken.None)).Should().BeEquivalentTo(before);
    }

    [Fact]
    public async Task GetOrgRs_returns_department_project_and_reference_counts()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.AddRange(new OrgR { Code = "AARE" }, new OrgR { Code = "ADNO" }, new OrgR { Code = "APLS" });
        db.OrgRFinancialDepartments.AddRange(
            new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" },
            new OrgRFinancialDepartment { FinancialDepartment = "AARE002", OrgR = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000002", NifaProjectNumber = "CA-D-ARE-2778-CG" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H" });
        db.OrgRProjectAdditions.AddRange(
            new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "AARE" },
            new OrgRProjectAddition { AccessionNumber = "1000003", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetOrgRs(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRDto>>().Subject.ToList();
        dtos.Should().HaveCount(3);
        var aare = dtos.Single(d => d.Code == "AARE");
        aare.FinancialDepartmentCount.Should().Be(2);
        aare.NifaProjectCount.Should().Be(2, "1000001 and 1000002 map through ARE; the manual addition of 1000001 does not double count");
        aare.ReferenceCount.Should().Be(4, "two departments, one NIFA department, one addition");
        var apls = dtos.Single(d => d.Code == "APLS");
        apls.FinancialDepartmentCount.Should().Be(0);
        apls.NifaProjectCount.Should().Be(1);
        apls.ReferenceCount.Should().Be(1);
        dtos.Single(d => d.Code == "ADNO").ReferenceCount.Should().Be(0);
    }

    [Fact]
    public async Task CreateOrgR_normalizes_code_and_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var created = await controller.CreateOrgR(" aare ", CancellationToken.None);
        var again = await controller.CreateOrgR("AARE", CancellationToken.None);

        created.Should().BeOfType<NoContentResult>();
        again.Should().BeOfType<NoContentResult>();
        db.OrgRs.Single().Code.Should().Be("AARE");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ELEVENCHARS")]
    [InlineData("BAD CODE")]
    public async Task CreateOrgR_rejects_invalid_codes(string code)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.CreateOrgR(code, CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task DeleteOrgR_refuses_when_referenced()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("AARE", CancellationToken.None);

        var conflict = result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().BeOfType<string>().Which.Should().Contain("1 mapping");
        db.OrgRs.Should().HaveCount(1);
    }

    [Fact]
    public async Task DeleteOrgR_refuses_to_delete_ADNO()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "ADNO" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("ADNO", CancellationToken.None);

        var conflict = result.Should().BeOfType<ConflictObjectResult>().Subject;
        conflict.Value.Should().BeOfType<string>().Which.Should()
            .Be("ADNO is required by the title code 1010 rule and cannot be deleted.");
        db.OrgRs.Should().HaveCount(1);
    }

    [Fact]
    public async Task DeleteOrgR_removes_unreferenced_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("AARE", CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        db.OrgRs.Should().BeEmpty();
    }

    [Fact]
    public async Task DeleteOrgR_returns_not_found_for_unknown_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.DeleteOrgR("NOPE", CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task GetFinancialDepartments_seeds_then_returns_in_cycle_rows_with_chart_segment_hierarchy()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRFinancialDepartments.AddRange(
            new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = "AARE" },
            new OrgRFinancialDepartment { FinancialDepartment = "OLD0001", OrgR = null });
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "AARE001", IncludeInReport = true });
        db.ChartSegments.AddRange(
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "AARE001", Description = "AARE Ag and Resource Economics", ParentLevel0Code = "100000A", ParentLevel1Code = "100000B", ParentLevel2Code = "AAES00C" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "100000A", Description = "UC Davis" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "100000B", Description = "UC Davis Campus" },
            new ChartSegment { SegmentName = "FinancialDepartment", Code = "AAES00C", Description = "College of Agricultural and Environmental Sciences" },
            new ChartSegment { SegmentName = "Fund", Code = "AARE001", Description = "not a department" });
        await db.SaveChangesAsync();
        var seeder = new FakeOrgRReviewSeeder();
        var controller = CreateController(db, seeder);

        var result = await controller.GetFinancialDepartments(CancellationToken.None);

        seeder.Calls.Should().Be(1);
        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRFinancialDepartmentDto>>().Subject.ToList();
        var aare = dtos.Should().ContainSingle().Subject;
        aare.FinancialDepartment.Should().Be("AARE001");
        aare.OrgR.Should().Be("AARE");
        aare.Description.Should().Be("AARE Ag and Resource Economics");
        aare.Hierarchy.Should().Equal(
            new HierarchyLevelDto("A", "100000A", "UC Davis"),
            new HierarchyLevelDto("B", "100000B", "UC Davis Campus"),
            new HierarchyLevelDto("C", "AAES00C", "College of Agricultural and Environmental Sciences"));
    }

    [Fact]
    public async Task GetFinancialDepartments_hides_departments_excluded_from_the_report()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRFinancialDepartments.AddRange(
            new OrgRFinancialDepartment { FinancialDepartment = "AARE001", OrgR = null },
            new OrgRFinancialDepartment { FinancialDepartment = "EXCL001", OrgR = null });
        db.SegmentClassifications.AddRange(
            new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "AARE001", IncludeInReport = true },
            new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "EXCL001", IncludeInReport = false });
        await db.SaveChangesAsync();
        var controller = CreateController(db, new FakeOrgRReviewSeeder());

        var result = await controller.GetFinancialDepartments(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRFinancialDepartmentDto>>().Subject.ToList();
        dtos.Should().ContainSingle().Which.FinancialDepartment.Should().Be("AARE001");
    }

    [Fact]
    public async Task SetFinancialDepartmentOrgR_updates_and_clears()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var set = await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest("aare"), CancellationToken.None);
        set.Should().BeOfType<NoContentResult>();
        db.OrgRFinancialDepartments.Single().OrgR.Should().Be("AARE");

        var cleared = await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest(null), CancellationToken.None);
        cleared.Should().BeOfType<NoContentResult>();
        db.OrgRFinancialDepartments.Single().OrgR.Should().BeNull();
    }

    [Fact]
    public async Task SetFinancialDepartmentOrgR_rejects_unknown_orgr_and_department()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRFinancialDepartments.Add(new OrgRFinancialDepartment { FinancialDepartment = "AARE001" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.SetFinancialDepartmentOrgR("AARE001", new SetOrgRRequest("ZZZZ"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
        (await controller.SetFinancialDepartmentOrgR("NOPE", new SetOrgRRequest(null), CancellationToken.None))
            .Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task GetNifaDepartments_returns_project_counts()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRNifaDepartments.AddRange(
            new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" },
            new OrgRNifaDepartment { NifaDepartment = "ESP", OrgR = null });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            // Projects is at NIFA x AE grain: a second row for the same
            // accession (e.g. a second AE project) must not double-count.
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" },
            new Project { AccessionNumber = "1000002", NifaProjectNumber = "CA-D-ARE-2778-CG" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H" });
        await db.SaveChangesAsync();
        var seeder = new FakeOrgRReviewSeeder();
        var controller = CreateController(db, seeder);

        var result = await controller.GetNifaDepartments(CancellationToken.None);

        seeder.Calls.Should().Be(1);
        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<OrgRNifaDepartmentDto>>().Subject.ToList();
        dtos.Single(d => d.NifaDepartment == "ARE").ProjectCount.Should().Be(2);
        dtos.Single(d => d.NifaDepartment == "ESP").ProjectCount.Should().Be(1);
    }

    [Fact]
    public async Task SetNifaDepartmentOrgR_updates_mapping()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "AARE" });
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.SetNifaDepartmentOrgR("ARE", new SetOrgRRequest("AARE"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        db.OrgRNifaDepartments.Single().OrgR.Should().Be("AARE");
    }

    [Fact]
    public async Task GetProjects_returns_default_rows_from_nifa_mapping_plus_manual_rows()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.AddRange(new OrgR { Code = "AARE" }, new OrgR { Code = "APLS" });
        db.OrgRNifaDepartments.AddRange(
            new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" },
            new OrgRNifaDepartment { NifaDepartment = "ESP", OrgR = null });
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water", ProjectDirector = "Doe" },
            new Project { AccessionNumber = "1000003", NifaProjectNumber = "CA-D-ESP-2880-H", Title = "Soil" });
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetProjects(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<ProjectOrgRDto>>().Subject.ToList();
        dtos.Should().HaveCount(2);
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.OrgR == "AARE" && d.Source == "Default" && d.Title == "Water");
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.OrgR == "APLS" && d.Source == "Manual");
    }

    [Fact]
    public async Task GetProjects_dedupes_default_rows_for_projects_at_nifa_x_ae_grain()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRNifaDepartments.Add(new OrgRNifaDepartment { NifaDepartment = "ARE", OrgR = "AARE" });
        // Projects is at NIFA x AE grain: this accession has two rows for the
        // same NifaProjectNumber (e.g. two AE projects). The Default rows
        // must still yield exactly one row for this OrgR.
        db.Projects.AddRange(
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water" },
            new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H", Title = "Water AE" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetProjects(CancellationToken.None);

        var dtos = result.Result.Should().BeOfType<OkObjectResult>().Subject.Value
            .Should().BeAssignableTo<IEnumerable<ProjectOrgRDto>>().Subject.ToList();
        dtos.Should().ContainSingle(d => d.AccessionNumber == "1000001" && d.Source == "Default");
    }

    [Fact]
    public async Task AddProject_validates_and_rejects_duplicates()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRs.Add(new OrgR { Code = "APLS" });
        db.Projects.Add(new Project { AccessionNumber = "1000001", NifaProjectNumber = "CA-D-ARE-2868-H" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "apls"), CancellationToken.None))
            .Should().BeOfType<NoContentResult>();
        db.OrgRProjectAdditions.Single().OrgR.Should().Be("APLS");

        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "APLS"), CancellationToken.None))
            .Should().BeOfType<ConflictObjectResult>();
        (await controller.AddProject(new AddProjectOrgRRequest("9999999", "APLS"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
        (await controller.AddProject(new AddProjectOrgRRequest("1000001", "ZZZZ"), CancellationToken.None))
            .Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task RemoveProject_deletes_manual_row_only()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = "1000001", OrgR = "APLS" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        (await controller.RemoveProject("1000001", "APLS", CancellationToken.None)).Should().BeOfType<NoContentResult>();
        db.OrgRProjectAdditions.Should().BeEmpty();
        (await controller.RemoveProject("1000001", "APLS", CancellationToken.None)).Should().BeOfType<NotFoundResult>();
    }
}
