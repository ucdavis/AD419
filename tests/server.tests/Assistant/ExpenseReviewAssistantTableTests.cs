using FluentAssertions;
using Server.Assistant;
using Server.Models.ExpenseReview;

namespace Server.Tests.Assistant;

public class ExpenseReviewAssistantTableTests
{
    [Fact]
    public void Columns_are_in_the_documented_order()
    {
        ExpenseReviewAssistantTable.Columns.Should().Equal(
            "id", "source", "amount", "included", "accountingPeriod", "sfn",
            "entity", "financialDept", "fund", "account", "aeProject",
            "purpose", "program", "activity", "exclusionReasons");
    }

    [Fact]
    public void ToRow_emits_codes_only_in_column_order()
    {
        var dto = new ExpenseReviewTransactionDto(
            "group-1",
            "AE",
            new ExpenseReviewCodeNameDto("3110", "UC Davis"),
            new ExpenseReviewCodeNameDto("ADNO003", "Plant Sciences"),
            new ExpenseReviewCodeNameDto("12345", "Hatch"),
            new ExpenseReviewCodeNameDto("770000", "Supplies"),
            new ExpenseReviewCodeNameDto("K30", "Project"),
            "2026-03",
            new ExpenseReviewCodeNameDto("44", "Research"),
            new ExpenseReviewCodeNameDto("000", "Default"),
            new ExpenseReviewCodeNameDto("000000", "Default"),
            "C",
            "Hatch",
            1234.56m,
            false,
            [new ExpenseReviewExclusionReasonDto("fund:excluded", "Excluded by fund", 2, 1234.56m)]);

        var row = ExpenseReviewAssistantTable.ToRow(dto);

        row.Should().HaveCount(ExpenseReviewAssistantTable.Columns.Count);
        row[0].Should().Be("group-1");
        row[1].Should().Be("AE");
        row[2].Should().Be(1234.56m);
        row[3].Should().Be(false);
        row[4].Should().Be("2026-03");
        row[5].Should().Be("C");
        row[6].Should().Be("3110");
        row[7].Should().Be("ADNO003");
        row[8].Should().Be("12345");
        row[9].Should().Be("770000");
        row[10].Should().Be("K30");
        row[11].Should().Be("44");
        row[12].Should().Be("000");
        row[13].Should().Be("000000");
        row[14].Should().BeEquivalentTo(new[] { "fund:excluded" });
    }
}
