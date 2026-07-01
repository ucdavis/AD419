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
}
