using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Tests.ChartStringSegments;

public class HierarchyMappingTests
{
    [Theory]
    [InlineData(typeof(DepartmentHierarchy), "DepartmentHierarchy")]
    [InlineData(typeof(AccountHierarchy), "AccountHierarchy")]
    [InlineData(typeof(FundHierarchy), "FundHierarchy")]
    [InlineData(typeof(ActivityHierarchy), "ActivityHierarchy")]
    public void Maps_to_data_schema_keyed_by_code(Type clr, string table)
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        var entityType = db.Model.FindEntityType(clr);

        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be("data");
        entityType.GetTableName().Should().Be(table);
        entityType.FindPrimaryKey()!.Properties.Select(p => p.Name).Should().Equal("Code");
    }

    [Fact]
    public void Department_levels_return_ordered_non_null_pairs()
    {
        var dept = new DepartmentHierarchy
        {
            Code = "031000",
            Description = "Plant Sciences",
            ParentLevelACode = "CAES", ParentLevelAName = "Ag & Env Sciences",
            ParentLevelBCode = "DIV1", ParentLevelBName = "Division One",
        };

        dept.Levels().Should().Equal(
            new HierarchyLevel("A", "CAES", "Ag & Env Sciences"),
            new HierarchyLevel("B", "DIV1", "Division One"));
    }

    [Fact]
    public void Fund_level_properties_have_max_lengths()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();
        var entity = db.Model.FindEntityType(typeof(FundHierarchy))!;

        entity.FindProperty("ParentLevel0Code")!.GetMaxLength().Should().Be(20);
        entity.FindProperty("ParentLevel0Name")!.GetMaxLength().Should().Be(1000);
        entity.FindProperty("Description")!.GetMaxLength().Should().Be(1000);
        // Code matches ChartStringSegment.Code (NVARCHAR(50)) so joins on Code align.
        entity.FindProperty("Code")!.GetMaxLength().Should().Be(50);
    }
}
