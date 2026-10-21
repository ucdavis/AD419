using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.SegmentClassifications;

public class SegmentClassificationSeedTests
{
    [Fact]
    public async Task EnsureSeeded_loads_ern_codes_from_csv()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await SegmentClassificationSeed.EnsureSeededAsync(db);

        var ern = db.SegmentClassifications
            .Where(segment => segment.SegmentType == SegmentType.Ern)
            .ToList();
        ern.Count.Should().BeGreaterThan(200);

        // REG (Regular Pay) has IncludeInAD419FTE = true and is not in the first 10 by code.
        var reg = ern.Single(segment => segment.Code == "REG");
        reg.IncludeInReport.Should().BeTrue();
        reg.Description.Should().Be("Regular Pay");

        // The first 10 by ordinal ERN code are left unset for demo.
        ern.OrderBy(segment => segment.Code, StringComparer.Ordinal)
            .Take(10)
            .All(segment => segment.IncludeInReport == null)
            .Should().BeTrue();
    }

    [Fact]
    public async Task Seeds_purpose_classifications_with_2025_defaults()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        db.ChartSegments.Add(new ChartSegment { SegmentName = "Purpose", Code = "44", Description = "Research" });
        await db.SaveChangesAsync();

        await SegmentClassificationSeed.EnsureSeededAsync(db);

        var purposes = db.SegmentClassifications
            .Where(s => s.SegmentType == SegmentType.Purpose)
            .ToDictionary(s => s.Code);

        string[] excluded = ["00", "40", "43", "60", "61", "62", "72", "76", "78", "80"];
        string[] included = ["44", "45"];
        purposes.Keys.Should().BeEquivalentTo(excluded.Concat(included));
        excluded.Should().OnlyContain(code => purposes[code].IncludeInReport == false);
        included.Should().OnlyContain(code => purposes[code].IncludeInReport == true);
        purposes["44"].Description.Should().Be("Research");
    }

    [Fact]
    public async Task EnsureSeeded_leaves_other_segment_types_to_the_import()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await SegmentClassificationSeed.EnsureSeededAsync(db);

        db.SegmentClassifications
            .Select(s => s.SegmentType)
            .Distinct()
            .ToList()
            .Should().BeEquivalentTo([SegmentType.Ern, SegmentType.Purpose]);
    }

    [Fact]
    public async Task EnsureSeeded_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await SegmentClassificationSeed.EnsureSeededAsync(db);
        var count = await db.SegmentClassifications.CountAsync();
        await SegmentClassificationSeed.EnsureSeededAsync(db);

        (await db.SegmentClassifications.CountAsync()).Should().Be(count);
    }
}
