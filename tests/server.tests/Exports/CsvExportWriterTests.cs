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
            [
                new ExportRow("D0123 - Plant, \"Sciences\"", "1234.50", null),
            ],
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
            [],
            [new CsvExportColumn<ExportRow>("Financial Dept", row => row.FinancialDept)],
            CancellationToken.None);

        output.ToArray().Should().NotBeEmpty();
    }

    private sealed record ExportRow(
        string FinancialDept,
        string Amount,
        string? Blank);

    private sealed class SyncFlushThrowingStream : MemoryStream
    {
        public override void Flush() =>
            throw new InvalidOperationException("Synchronous flush is disallowed.");

        public override Task FlushAsync(CancellationToken cancellationToken) =>
            Task.CompletedTask;
    }
}
