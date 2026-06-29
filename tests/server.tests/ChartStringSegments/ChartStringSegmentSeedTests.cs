using FluentAssertions;
using Server.Core.Data;
using Server.Core.Domain;

namespace Server.Tests.ChartStringSegments;

public class ChartStringSegmentSeedTests
{
    [Fact]
    public async Task EnsureSeeded_inserts_rows_when_table_is_empty()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        db.ChartStringSegments.Count().Should().Be(ChartStringSegmentSeed.Rows.Count);
    }

    [Fact]
    public async Task EnsureSeeded_is_idempotent()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await ChartStringSegmentSeed.EnsureSeededAsync(db);
        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        db.ChartStringSegments.Count().Should().Be(ChartStringSegmentSeed.Rows.Count);
    }

    [Fact]
    public async Task EnsureSeeded_only_sets_sfn_for_fund_rows()
    {
        using var db = TestDbContextFactory.CreateInMemory();

        await ChartStringSegmentSeed.EnsureSeededAsync(db);

        db.ChartStringSegments
            .Where(segment => segment.Sfn != null)
            .All(segment => segment.SegmentType == SegmentType.Fund)
            .Should().BeTrue();
    }
}
