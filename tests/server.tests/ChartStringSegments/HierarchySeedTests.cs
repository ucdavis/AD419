using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;

namespace Server.Tests.ChartStringSegments;

public class HierarchySeedTests
{
    [Fact]
    public async Task EnsureSeeded_inserts_hierarchy_rows_for_seeded_codes()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        (await db.DepartmentHierarchies.CountAsync()).Should().BeGreaterThan(0);
        (await db.FundHierarchies.FindAsync("45530")).Should().NotBeNull();
        (await db.AccountHierarchies.FindAsync("500000")).Should().NotBeNull();
        (await db.ActivityHierarchies.FindAsync("44A100")).Should().NotBeNull();
    }

    [Fact]
    public async Task EnsureSeeded_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await HierarchySeed.EnsureSeededAsync(db);
        var count = await db.FundHierarchies.CountAsync();
        await HierarchySeed.EnsureSeededAsync(db);

        (await db.FundHierarchies.CountAsync()).Should().Be(count);
    }
}
