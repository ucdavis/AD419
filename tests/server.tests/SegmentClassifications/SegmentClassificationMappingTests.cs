using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.SegmentClassifications;

public class SegmentClassificationMappingTests
{
    [Fact]
    public void Maps_to_data_schema_with_composite_key()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        var entityType = db.Model.FindEntityType(typeof(SegmentClassification));

        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be("data");
        entityType.GetTableName().Should().Be("SegmentClassifications");
        entityType.FindPrimaryKey()!.Properties.Select(p => p.Name)
            .Should().Equal(nameof(SegmentClassification.SegmentType), nameof(SegmentClassification.Code));
    }

    [Fact]
    public void Stores_segment_type_as_string()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        var property = db.Model.FindEntityType(typeof(SegmentClassification))!
            .FindProperty(nameof(SegmentClassification.SegmentType));

        property!.GetProviderClrType().Should().Be(typeof(string));
    }

    [Fact]
    public void Sfn_column_allows_ten_characters()
    {
        using var db = TestDbContextFactory.CreateDataInMemory();

        var property = db.Model.FindEntityType(typeof(SegmentClassification))!
            .FindProperty(nameof(SegmentClassification.Sfn));

        property!.GetMaxLength().Should().Be(10);
    }
}
