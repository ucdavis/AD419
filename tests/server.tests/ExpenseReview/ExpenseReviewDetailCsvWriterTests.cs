using System.Globalization;
using CsvHelper;
using FluentAssertions;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewDetailCsvWriterTests
{
    [Theory]
    [InlineData("A1", "Activity One", "A1 - Activity One")]
    [InlineData("A1", "A1 - Activity One", "A1 - Activity One")]
    [InlineData("A1", "A1 Activity One", "A1 Activity One")]
    [InlineData("A1", "A1", "A1")]
    [InlineData("A1", "A10 - Another activity", "A1 - A10 - Another activity")]
    [InlineData("A1", null, "A1")]
    [InlineData("A1", "", "A1")]
    [InlineData("A1", "  ", "A1")]
    [InlineData(null, "Activity One", "")]
    [InlineData("", "Activity One", "")]
    [InlineData("  ", "Activity One", "")]
    [InlineData(null, null, "")]
    public async Task WriteAsync_formats_chart_segments_without_repeating_codes(
        string? code, string? name, string expected)
    {
        var segment = new ExpenseReviewCodeNameDto(code, name);
        var group = new ExpenseReviewTransactionDto(
            "group-1", "AE", segment, segment, segment, segment, segment, "Nov-24",
            segment, segment, segment, "220", "AES", 50m, true, []);
        var cycle = new FiscalYearCycle("FY25", new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30));
        await using var output = new MemoryStream();

        await ExpenseReviewDetailCsvWriter.WriteAsync(
            output, Rows(), cycle, group, CancellationToken.None);

        output.Position = 0;
        using var csv = new CsvReader(new StreamReader(output), CultureInfo.InvariantCulture);
        (await csv.ReadAsync()).Should().BeTrue();
        csv.ReadHeader();
        (await csv.ReadAsync()).Should().BeTrue();
        foreach (var column in new[] { "Entity", "Financial Dept", "Fund", "Account", "Project", "Purpose", "Program", "Activity" })
        {
            csv.GetField(column).Should().Be(expected, $"{column} should use the shared chart segment format");
        }
    }

    private static async IAsyncEnumerable<ExpenseReviewTransactionDetailDto> Rows()
    {
        await Task.Yield();
        yield return new ExpenseReviewTransactionDetailDto { Id = "1", Amount = 50m };
    }
}
