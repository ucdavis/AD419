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
        using var db = TestDbContextFactory.CreateInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        (await db.AccountHierarchies.CountAsync()).Should().BeGreaterThan(100);
        (await db.FundHierarchies.CountAsync()).Should().BeGreaterThan(50);
        (await db.ActivityHierarchies.CountAsync()).Should().BeGreaterThan(20);
        (await db.AccountHierarchies.FindAsync("500000")).Should().NotBeNull();
        (await db.FundHierarchies.FindAsync("71549")).Should().NotBeNull();
        (await db.ActivityHierarchies.FindAsync("202042")).Should().NotBeNull();
    }

    [Fact]
    public async Task EnsureSeeded_synthesizes_department_levels_a_through_g()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await HierarchySeed.EnsureSeededAsync(db);

        var department = await db.DepartmentHierarchies.FindAsync("ANUT006");
        department.Should().NotBeNull();
        // Fabricated top levels plus the real D-G chain from the source file.
        department!.Levels().Select(level => level.Level)
            .Should().Equal("A", "B", "C", "D", "E", "F", "G");
        department.ParentLevelACode.Should().Be("UCD");
        department.ParentLevelDCode.Should().Be("ACL100D");
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
