using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.ChartStringSegments;

namespace Server.Tests.ChartStringSegments;

public class ChartStringSegmentsControllerTests
{
    [Fact]
    public async Task Get_returns_all_segments()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.AddRange(
            new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "45530", Description = "AES", IncludeInReport = true, Sfn = "220" },
            new ChartStringSegment { SegmentType = SegmentType.Account, Code = "500000", Description = "S and E", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeAssignableTo<IEnumerable<ChartStringSegmentDto>>()
            .Which.Should().HaveCount(2);
    }

    [Fact]
    public async Task Get_includes_hierarchy_for_segment_with_matching_code()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" });
        db.FundHierarchies.Add(new FundHierarchy
        {
            Code = "45530",
            ParentLevel0Code = "STATE", ParentLevel0Name = "State Funds",
            ParentLevel1Code = "APPROP", ParentLevel1Name = "Appropriations",
        });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<ChartStringSegmentDto>>().Subject.Single();
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
        using var db = TestDbContextFactory.CreateInMemory();
        const string code = "12345";
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = segmentType, Code = code, IncludeInReport = null });

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
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<ChartStringSegmentDto>>().Subject.Single();
        dto.Hierarchy.Should().Equal(new HierarchyLevelDto(expectedLevel, "X", "XName"));
    }

    [Fact]
    public async Task Get_returns_empty_hierarchy_when_no_matching_row()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Account, Code = "500000", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.Get(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var dto = ok.Value.Should().BeAssignableTo<IEnumerable<ChartStringSegmentDto>>().Subject.Single();
        dto.Hierarchy.Should().BeEmpty();
    }

    [Fact]
    public async Task Patch_updates_include_flag()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null, Sfn = "219" });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "201"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.ChartStringSegments.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("201");
    }

    [Fact]
    public async Task Patch_returns_not_found_for_missing_segment()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "00000", false, null), CancellationToken.None);

        result.Should().BeOfType<NotFoundResult>();
    }

    [Fact]
    public async Task Patch_returns_bad_request_for_unknown_segment_type()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Nonsense", "00000", false, null), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_sets_sfn_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "220"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.ChartStringSegments.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("220");
    }

    [Fact]
    public async Task Patch_clears_sfn_when_fund_excluded()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "45530", IncludeInReport = true, Sfn = "220" });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "45530", false, null), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.ChartStringSegments.FindAsync(SegmentType.Fund, "45530");
        updated!.IncludeInReport.Should().BeFalse();
        updated.Sfn.Should().BeNull();
    }

    [Fact]
    public async Task Patch_rejects_invalid_sfn_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "999"), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_rejects_sfn_on_non_fund_segment()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Account, Code = "500000", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Account", "500000", true, "201"), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Patch_accepts_multiple_marker_for_included_fund()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        db.ChartStringSegments.Add(new ChartStringSegment { SegmentType = SegmentType.Fund, Code = "70575", IncludeInReport = null });
        await db.SaveChangesAsync();
        var controller = new ChartStringSegmentsController(db);

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "Multiple"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.ChartStringSegments.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("Multiple");
    }
}
