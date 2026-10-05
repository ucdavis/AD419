using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Helpers;
using Server.Models.SegmentClassifications;
using Server.Tests.Helpers;

namespace Server.Tests.SegmentClassifications;

public class SegmentClassificationsControllerTests
{
    private static SegmentClassificationsController CreateController(DataDbContext db) => new(db)
    {
        ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
    };

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Failure_logs_submitted_identifiers_without_leaking_to_next_request(bool exception)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);
        var context = controller.HttpContext;
        context.Request.Path = "/api/segmentclassifications";
        context.Request.Method = "PATCH";
        var request = new UpdateClassificationRequest(exception ? "Fund" : "Unknown", "45530", true, "220");
        if (exception)
        {
            db.Dispose();
        }
        var logger = new RecordingLogger<ApiFailureLoggingMiddleware>();
        var middleware = new ApiFailureLoggingMiddleware(async ctx =>
        {
            if (ctx == context)
            {
                using var inner = logger.BeginScope(new Dictionary<string, object?> { ["InnerScope"] = true });
                var result = await controller.UpdateClassification(request, CancellationToken.None);
                ctx.Response.StatusCode = ((BadRequestObjectResult)result).StatusCode!.Value;
            }
            else
            {
                ctx.Response.StatusCode = 403;
            }
        }, logger);

        if (exception)
        {
            await FluentActions.Awaiting(() => middleware.InvokeAsync(context)).Should().ThrowAsync<ObjectDisposedException>();
        }
        else
        {
            await middleware.InvokeAsync(context);
        }

        var entry = logger.Entries.Should().ContainSingle().Subject;
        entry.Fields["Operation"].Should().Be("UpdateClassification");
        entry.Fields["SegmentType"].Should().Be(request.SegmentType);
        entry.Fields["Code"].Should().Be("45530");
        entry.Fields.Should().NotContainKey("InnerScope");
        entry.Fields.Should().NotContainKey("Sfn");
        entry.Fields.Should().NotContainKey("IncludeInReport");

        var nextContext = new DefaultHttpContext();
        nextContext.Request.Path = "/api/segmentclassifications";
        nextContext.Request.Method = "PATCH";
        await middleware.InvokeAsync(nextContext);
        logger.Entries.Should().HaveCount(2);
        logger.Entries.Last().Fields.Should().NotContainKey("Operation");
        logger.Entries.Last().Fields.Should().NotContainKey("SegmentType");
        logger.Entries.Last().Fields.Should().NotContainKey("Code");
    }

    [Fact]
    public async Task Get_returns_all_segments()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.AddRange(
            new SegmentClassification { SegmentType = SegmentType.Fund, Code = "45530", Description = "AES", IncludeInReport = true, Sfn = "220" },
            new SegmentClassification { SegmentType = SegmentType.Account, Code = "500000", Description = "S and E", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>()
            .Which.Should().HaveCount(2);
    }

    [Fact]
    public async Task Get_includes_hierarchy_for_segment_with_matching_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" });
        db.FundHierarchies.Add(new FundHierarchy
        {
            Code = "45530",
            ParentLevel0Code = "STATE", ParentLevel0Name = "State Funds",
            ParentLevel1Code = "APPROP", ParentLevel1Name = "Appropriations",
        });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>().Subject.Single();
        dto.Hierarchy.Should().Equal(
            new HierarchyLevelDto("A", "STATE", "State Funds"),
            new HierarchyLevelDto("B", "APPROP", "Appropriations"));
    }

    [Theory]
    [InlineData(SegmentType.FinancialDepartment, "A")]
    [InlineData(SegmentType.Account, "A")]
    [InlineData(SegmentType.Fund, "A")]
    [InlineData(SegmentType.Activity, "A")]
    [InlineData(SegmentType.Purpose, "A")]
    public async Task Get_reads_hierarchy_from_the_matching_segment_types_own_table(
        SegmentType segmentType, string expectedLevel)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        const string code = "12345";
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = segmentType, Code = code, IncludeInReport = null });

        switch (segmentType)
        {
            case SegmentType.FinancialDepartment:
                db.DepartmentHierarchies.Add(new DepartmentHierarchy
                {
                    Code = code, ParentLevelACode = "X", ParentLevelAName = "XName",
                });
                break;
            case SegmentType.Account:
                db.AccountHierarchies.Add(new AccountHierarchy
                {
                    Code = code, ParentLevel0Code = "X", ParentLevel0Name = "XName",
                });
                break;
            case SegmentType.Fund:
                db.FundHierarchies.Add(new FundHierarchy
                {
                    Code = code, ParentLevel0Code = "X", ParentLevel0Name = "XName",
                });
                break;
            case SegmentType.Activity:
                db.ActivityHierarchies.Add(new ActivityHierarchy
                {
                    Code = code, ParentLevel0Code = "X", ParentLevel0Name = "XName",
                });
                break;
            case SegmentType.Purpose:
                db.PurposeHierarchies.Add(new PurposeHierarchy
                {
                    Code = code, ParentLevel0Code = "X", ParentLevel0Name = "XName",
                });
                break;
        }

        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>().Subject.Single();
        dto.Hierarchy.Should().Equal(new HierarchyLevelDto(expectedLevel, "X", "XName"));
    }

    [Fact]
    public async Task Get_returns_empty_hierarchy_when_no_matching_row()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Account, Code = "500000", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>().Subject.Single();
        dto.Hierarchy.Should().BeEmpty();
    }

    [Fact]
    public async Task Patch_updates_include_flag()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null, Sfn = "219" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "201"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("201");
    }

    [Fact]
    public async Task Patch_returns_not_found_for_missing_segment()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "00000", false, null), CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task Patch_returns_bad_request_for_unknown_segment_type()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Nonsense", "00000", false, null), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_sets_sfn_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "220"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("220");
    }

    [Fact]
    public async Task Patch_clears_sfn_when_fund_excluded()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "45530", false, null), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "45530");
        updated!.IncludeInReport.Should().BeFalse();
        updated.Sfn.Should().BeNull();
    }

    [Fact]
    public async Task Patch_rejects_invalid_sfn_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "999"), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_rejects_sfn_on_non_fund_segment()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Account, Code = "500000", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Account", "500000", true, "201"), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_accepts_multiple_marker_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "Multiple"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("Multiple");
    }
}
