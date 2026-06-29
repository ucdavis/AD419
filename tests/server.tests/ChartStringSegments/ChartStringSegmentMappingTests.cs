using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.ChartStringSegments;

public class ChartStringSegmentMappingTests
{
    [Fact]
    public void Maps_to_data_schema_with_composite_key()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var entityType = db.Model.FindEntityType(typeof(ChartStringSegment));

        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be("data");
        entityType.GetTableName().Should().Be("ChartStringSegments");
        entityType.FindPrimaryKey()!.Properties.Select(p => p.Name)
            .Should().Equal(nameof(ChartStringSegment.SegmentType), nameof(ChartStringSegment.Code));
    }

    [Fact]
    public void Stores_segment_type_as_string()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        var property = db.Model.FindEntityType(typeof(ChartStringSegment))!
            .FindProperty(nameof(ChartStringSegment.SegmentType));

        property!.GetProviderClrType().Should().Be(typeof(string));
    }
}
