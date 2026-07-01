using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.ChartStringSegments;

public class ChartStringSegmentSeedTests
{
    [Fact]
    public async Task EnsureSeeded_derives_one_segment_per_hierarchy_row()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        await HierarchySeed.EnsureSeededAsync(db);

        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        var expected =
            await db.AccountHierarchies.CountAsync() +
            await db.FundHierarchies.CountAsync() +
            await db.ActivityHierarchies.CountAsync() +
            await db.DepartmentHierarchies.CountAsync() +
            db.ChartStringSegments.Count(segment => segment.SegmentType == SegmentType.Ern);
        (await db.ChartStringSegments.CountAsync()).Should().Be(expected);
    }

    [Fact]
    public async Task EnsureSeeded_loads_ern_codes_from_csv()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        await HierarchySeed.EnsureSeededAsync(db);

        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        var ern = db.ChartStringSegments
            .Where(segment => segment.SegmentType == SegmentType.Ern)
            .ToList();
        ern.Count.Should().BeGreaterThan(200);

        // REG (Regular Pay) has IncludeInAD419FTE = true and is not in the first 10 by code.
        var reg = ern.Single(segment => segment.Code == "REG");
        reg.IncludeInReport.Should().BeTrue();
        reg.Description.Should().Be("Regular Pay");

        // The first 10 by ordinal DOS code are left unset for demo.
        ern.OrderBy(segment => segment.Code, StringComparer.Ordinal)
            .Take(10)
            .All(segment => segment.IncludeInReport == null)
            .Should().BeTrue();
    }

    [Fact]
    public async Task EnsureSeeded_maps_segment_types_to_their_hierarchy()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        await HierarchySeed.EnsureSeededAsync(db);

        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        // Account 500000 comes from AccountHierarchy, so it is an Account segment.
        var account = await db.ChartStringSegments.FindAsync(SegmentType.Account, "500000");
        account.Should().NotBeNull();
        // Fund 71549 comes from FundHierarchy.
        (await db.ChartStringSegments.FindAsync(SegmentType.Fund, "71549")).Should().NotBeNull();
    }

    [Fact]
    public async Task EnsureSeeded_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateInMemory();
        await HierarchySeed.EnsureSeededAsync(db);

        await ChartStringSegmentSeed.EnsureSeededAsync(db);
        var count = await db.ChartStringSegments.CountAsync();
        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        (await db.ChartStringSegments.CountAsync()).Should().Be(count);
    }
}
