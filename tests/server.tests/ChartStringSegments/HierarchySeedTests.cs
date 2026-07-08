using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.ChartStringSegments;

public class HierarchySeedTests
{
    [Fact]
    public async Task EnsureSeeded_loads_rows_from_the_embedded_csvs()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        (await db.AccountHierarchies.CountAsync()).Should().BeGreaterThan(100);
        (await db.FundHierarchies.CountAsync()).Should().BeGreaterThan(50);
        (await db.ActivityHierarchies.CountAsync()).Should().BeGreaterThan(20);
        (await db.AccountHierarchies.FindAsync("500000")).Should().NotBeNull();
        (await db.FundHierarchies.FindAsync("71549")).Should().NotBeNull();
        (await db.ActivityHierarchies.FindAsync("202042")).Should().NotBeNull();
    }

    [Fact]
    public async Task EnsureSeeded_synthesizes_department_levels_a_through_f()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        var department = await db.DepartmentHierarchies.FindAsync("ANUT006");
        department.Should().NotBeNull();
        // Fabricated top levels plus the real D-F chain from the source file.
        // Level G is omitted: it always repeats the row's own code.
        department!.Levels().Select(level => level.Level)
            .Should().Equal("A", "B", "C", "D", "E", "F");
        department.ParentLevelACode.Should().Be("UCD");
        department.ParentLevelDCode.Should().Be("ACL100D");
    }

    [Fact]
    public async Task Seeds_purpose_hierarchy_leaves()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        db.PurposeHierarchies.Should().HaveCount(18);
        var research = db.PurposeHierarchies.Single(p => p.Code == "44");
        research.Levels().Should().Equal(
            new HierarchyLevel("A", "1A", "Purpose Categories"),
            new HierarchyLevel("B", "1D", "Organized Research D"));
    }

    [Fact]
    public async Task Seeding_nulls_levels_that_repeat_the_rows_own_code()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        // The account CSV repeats the leaf code at the deepest level (e.g. 400900).
        var account = db.AccountHierarchies.Single(a => a.Code == "400900");
        account.ParentLevel5Code.Should().BeNull();
        account.ParentLevel5Name.Should().BeNull();

        // No account row keeps any level equal to its own code.
        db.AccountHierarchies.AsEnumerable()
            .Should().OnlyContain(a => a.Levels().All(l => l.Code != a.Code));

        // Department rows no longer carry the self-referencing G level.
        db.DepartmentHierarchies.AsEnumerable()
            .Should().OnlyContain(d => d.Levels().All(l => l.Code != d.Code));
    }

    [Fact]
    public async Task EnsureSeeded_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        await HierarchySeed.EnsureSeededAsync(db);
        var count = await db.FundHierarchies.CountAsync();
        await HierarchySeed.EnsureSeededAsync(db);

        (await db.FundHierarchies.CountAsync()).Should().Be(count);
    }
}
