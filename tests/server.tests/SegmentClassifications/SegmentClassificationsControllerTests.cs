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
        context.Request.RouteValues["controller"] = "SegmentClassifications";
        context.Request.RouteValues["action"] = "UpdateClassification";
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
        entry.Fields["action"].Should().Be("UpdateClassification");
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
        db.ClassificationCandidates.AddRange(
            new ClassificationCandidate { SegmentType = SegmentType.Fund, Code = "45530" },
            new ClassificationCandidate { SegmentType = SegmentType.Account, Code = "500000" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>()
            .Which.Should().HaveCount(2);
    }

    [Fact]
    public async Task Get_leaves_out_segments_that_are_not_classification_candidates()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.AddRange(
            new SegmentClassification { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" },
            new SegmentClassification { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null },
            new SegmentClassification { SegmentType = SegmentType.Account, Code = "45530", IncludeInReport = null });
        // Same code under another type is not a match.
        db.ClassificationCandidates.Add(new ClassificationCandidate { SegmentType = SegmentType.Fund, Code = "45530" });
        await db.SaveChangesAsync();
        var controller = new SegmentClassificationsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>()
            .Which.Should().ContainSingle()
            .Which.Code.Should().Be("45530");
    }

    [Fact]
    public async Task Get_matches_candidates_to_segments_ignoring_code_case()
    {
        // SQL Server compares codes case-insensitively, so the view can return a
        // casing that differs from the seeded segment row.
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(
            new SegmentClassification { SegmentType = SegmentType.FinancialDepartment, Code = "D1", IncludeInReport = null });
        db.ClassificationCandidates.Add(new ClassificationCandidate { SegmentType = SegmentType.FinancialDepartment, Code = "d1" });
        await db.SaveChangesAsync();
        var controller = new SegmentClassificationsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>()
            .Which.Should().ContainSingle()
            .Which.Code.Should().Be("D1");
    }

    [Fact]
    public async Task Get_builds_hierarchy_from_chart_segments_with_parent_names()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" });
        db.ClassificationCandidates.Add(new ClassificationCandidate { SegmentType = SegmentType.Fund, Code = "45530" });
        db.ChartSegments.AddRange(
            new ChartSegment
            {
                SegmentName = "Fund", Code = "45530", Description = "AES",
                ParentLevel0Code = "STATE", ParentLevel1Code = "APPROP", ParentLevel2Code = "45530",
            },
            new ChartSegment { SegmentName = "Fund", Code = "STATE", Description = "State Funds" },
            new ChartSegment { SegmentName = "Fund", Code = "APPROP", Description = "Appropriations" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>().Subject.Single();
        // The warehouse repeats a code as its own level; that level is dropped.
        dto.Hierarchy.Should().Equal(
            new HierarchyLevelDto("A", "STATE", "State Funds"),
            new HierarchyLevelDto("B", "APPROP", "Appropriations"));
    }

    [Theory]
    [InlineData(SegmentType.FinancialDepartment, "FinancialDepartment")]
    [InlineData(SegmentType.Account, "Account")]
    [InlineData(SegmentType.Fund, "Fund")]
    [InlineData(SegmentType.Activity, "Activity")]
    [InlineData(SegmentType.Purpose, "Purpose")]
    public async Task Get_reads_hierarchy_from_the_matching_chart_segment(
        SegmentType segmentType, string segmentName)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        const string code = "12345";
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = segmentType, Code = code, IncludeInReport = null });
        db.ClassificationCandidates.Add(new ClassificationCandidate { SegmentType = segmentType, Code = code });
        // The same codes under another segment must not be picked up.
        var otherName = segmentName == "Fund" ? "Account" : "Fund";
        db.ChartSegments.AddRange(
            new ChartSegment { SegmentName = segmentName, Code = code, ParentLevel0Code = "X" },
            new ChartSegment { SegmentName = segmentName, Code = "X", Description = "XName" },
            new ChartSegment { SegmentName = otherName, Code = code, ParentLevel0Code = "Y" },
            new ChartSegment { SegmentName = otherName, Code = "X", Description = "Wrong" });
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<SegmentClassificationDto>>().Subject.Single();
        dto.Hierarchy.Should().Equal(new HierarchyLevelDto("A", "X", "XName"));
    }

    [Fact]
    public async Task Get_returns_empty_hierarchy_when_no_matching_row()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.SegmentClassifications.Add(new SegmentClassification { SegmentType = SegmentType.Account, Code = "500000", IncludeInReport = null });
        db.ClassificationCandidates.Add(new ClassificationCandidate { SegmentType = SegmentType.Account, Code = "500000" });
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
