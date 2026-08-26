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
                    "AE:1",
                    "1",
                    "AE",
                    new ExpenseReviewCodeNameDto("D0123", "Plant, \"Sciences\""),
                    new ExpenseReviewCodeNameDto(null, null),
                    new ExpenseReviewCodeNameDto("500000", null),
                    new ExpenseReviewCodeNameDto("K1234", "Tomato Project"),
                    "",
                    "220",
                    "AES, Federal",
                    1234.5m,
                    null,
                    false,
                    false)
            ),
            ExpenseReviewRequestParser.DefaultCsvColumnIds,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray());

        csv.Should().StartWith('\ufeff' + "Financial Dept,Fund,Account,AE Project,Accounting Period,Source,SFN,Amount,FTE,Include State\r\n");
        csv.Should().Contain("\"D0123 - Plant, \"\"Sciences\"\"\"");
        csv.Should().Contain(",,500000,K1234 - Tomato Project,,AE,\"220 - AES, Federal\",1234.50,,Excluded");
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
