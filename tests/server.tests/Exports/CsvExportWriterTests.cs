using System.Text;
using FluentAssertions;
using Server.Exports;

namespace Server.Tests.Exports;

public class CsvExportWriterTests
{
    [Fact]
    public async Task WriteAsync_writes_excel_friendly_csv_with_headers_and_escaped_values()
    {
        await using var output = new MemoryStream();

        await CsvExportWriter.WriteAsync(
            output,
            ToAsyncEnumerable(
                new ExportRow("D0123 - Plant, \"Sciences\"", "1234.50", null)
            ),
            [
                new CsvExportColumn<ExportRow>("Financial Dept", row => row.FinancialDept),
                new CsvExportColumn<ExportRow>("Amount", row => row.Amount),
                new CsvExportColumn<ExportRow>("Blank", row => row.Blank),
            ],
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray());

        csv.Should().Be('\ufeff' + "Financial Dept,Amount,Blank\r\n\"D0123 - Plant, \"\"Sciences\"\"\",1234.50,\r\n");
    }

    [Fact]
    public async Task WriteAsync_does_not_require_synchronous_flush()
    {
        await using var output = new SyncFlushThrowingStream();

        await CsvExportWriter.WriteAsync(
            output,
            ToAsyncEnumerable<ExportRow>(),
            [new CsvExportColumn<ExportRow>("Financial Dept", row => row.FinancialDept)],
            CancellationToken.None);

        output.ToArray().Should().NotBeEmpty();
    }

    [Fact]
    public async Task WriteAsync_enumerates_rows_during_writing()
    {
        await using var output = new MemoryStream();
        var rowsEnumerated = 0;

        await CsvExportWriter.WriteAsync(
            output,
            CreateRows(),
            [new CsvExportColumn<ExportRow>("Financial Dept", row => row.FinancialDept)],
            CancellationToken.None);

        rowsEnumerated.Should().Be(1);

        async IAsyncEnumerable<ExportRow> CreateRows()
        {
            rowsEnumerated++;
            await Task.Yield();
            yield return new ExportRow("D0123", "1234.50", null);
        }
    }

    private sealed record ExportRow(
        string FinancialDept,
        string Amount,
        string? Blank);

    private static async IAsyncEnumerable<T> ToAsyncEnumerable<T>(params T[] rows)
    {
        foreach (var row in rows)
        {
            await Task.Yield();
            yield return row;
        }
    }

    private sealed class SyncFlushThrowingStream : MemoryStream
    {
        public override void Flush() =>
            throw new InvalidOperationException("Synchronous flush is disallowed.");

        public override Task FlushAsync(CancellationToken cancellationToken) =>
            Task.CompletedTask;
    }
}
