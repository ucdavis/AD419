using System.Text;
using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewCsvWriterTests
{
    [Fact]
    public async Task WriteAsync_uses_expected_headers_and_escapes_values()
    {
        await using var output = new MemoryStream();

        await ExpenseReviewCsvWriter.WriteAsync(
            output,
            ToAsyncEnumerable(
                new ExpenseReviewTransactionDto(
                    "group-1",
                    "AE",
                    new ExpenseReviewCodeNameDto("3310", "Entity"),
                    new ExpenseReviewCodeNameDto("D0123", "Plant, \"Sciences\""),
                    new ExpenseReviewCodeNameDto(null, null),
                    new ExpenseReviewCodeNameDto("500000", null),
                    new ExpenseReviewCodeNameDto("K1234", "Tomato Project"),
                    "Oct-24",
                    new ExpenseReviewCodeNameDto("44", "Research"),
                    new ExpenseReviewCodeNameDto(null, null),
                    new ExpenseReviewCodeNameDto("A1", "Activity One"),
                    "220",
                    "AES, Federal",
                    1234.5m,
                    false,
                    [
                        new ExpenseReviewExclusionReasonDto(
                            "fund:F2:excluded",
                            "Fund F2 excluded",
                            2,
                            1234.5m),
                    ])
            ),
            false,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray());

        csv.Should().StartWith('\ufeff' + "Source,Entity,Fund,Financial Dept,Account,Purpose,Program,Project,Activity,SFN,Amount,Include State,Exclusion Reasons\r\n");
        csv.Should().Contain("\"D0123 - Plant, \"\"Sciences\"\"\"");
        csv.Should().Contain("AE,3310 - Entity,,\"D0123 - Plant, \"\"Sciences\"\"\",500000,44 - Research,,K1234 - Tomato Project,A1 - Activity One,\"220 - AES, Federal\",1234.50,Excluded,\"Fund F2 excluded · $1,234.50 · 2 rows\"");
    }

    [Fact]
    public async Task WriteAsync_includes_accounting_period_when_displayed_by_period()
    {
        await using var output = new MemoryStream();

        await ExpenseReviewCsvWriter.WriteAsync(
            output,
            ToAsyncEnumerable(
                new ExpenseReviewTransactionDto(
                    "group-1",
                    "UCP",
                    new ExpenseReviewCodeNameDto("3310", "Entity"),
                    new ExpenseReviewCodeNameDto("D0123", "Department"),
                    new ExpenseReviewCodeNameDto("13U02", "Fund"),
                    new ExpenseReviewCodeNameDto("500000", "Account"),
                    new ExpenseReviewCodeNameDto("K1234", "Tomato Project"),
                    "Nov-24",
                    new ExpenseReviewCodeNameDto("44", "Research"),
                    new ExpenseReviewCodeNameDto("PG1", "Program"),
                    new ExpenseReviewCodeNameDto("A1", "Activity One"),
                    "220",
                    "AES",
                    50m,
                    true,
                    [])
            ),
            true,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray());

        csv.Should().StartWith('\ufeff' + "Source,Accounting Period,Entity,Fund,Financial Dept,Account,Purpose,Program,Project,Activity,SFN,Amount,Include State,Exclusion Reasons\r\n");
        csv.Should().Contain("UCP,Nov-24,3310 - Entity,13U02 - Fund,D0123 - Department,500000 - Account,44 - Research,PG1 - Program,K1234 - Tomato Project,A1 - Activity One,220 - AES,50.00,Included,");
    }

    private static async IAsyncEnumerable<T> ToAsyncEnumerable<T>(params T[] rows)
    {
        foreach (var row in rows)
        {
            await Task.Yield();
            yield return row;
        }
    }
}
