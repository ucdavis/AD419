using System.Globalization;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;

namespace Server.Exports;

public sealed record CsvExportColumn<T>(
    string Header,
    Func<T, string?> Value);

public static class CsvExportWriter
{
    public static async Task WriteAsync<T>(
        Stream output,
        IAsyncEnumerable<T> rows,
        IReadOnlyList<CsvExportColumn<T>> columns,
        CancellationToken cancellationToken)
    {
        await using var writer = new StreamWriter(
            output,
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: true),
            leaveOpen: true);
        await using var csv = new CsvWriter(writer, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            NewLine = "\r\n",
        }, leaveOpen: true);

        foreach (var column in columns)
        {
            csv.WriteField(column.Header);
        }

        await csv.NextRecordAsync();

        await foreach (var row in rows.WithCancellation(cancellationToken))
        {
            cancellationToken.ThrowIfCancellationRequested();

            foreach (var column in columns)
            {
                csv.WriteField(column.Value(row) ?? string.Empty);
            }

            await csv.NextRecordAsync();
        }

        await csv.FlushAsync();
        await writer.FlushAsync(cancellationToken);
    }
}
