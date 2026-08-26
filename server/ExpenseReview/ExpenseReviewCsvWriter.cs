using System.Globalization;
using Server.Exports;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public static class ExpenseReviewCsvWriter
{
    private static readonly IReadOnlyDictionary<string, CsvExportColumn<ExpenseReviewTransactionDto>> Columns =
        new Dictionary<string, CsvExportColumn<ExpenseReviewTransactionDto>>(StringComparer.OrdinalIgnoreCase)
        {
            ["financialDept"] = new("Financial Dept", row => FormatCodeName(row.FinancialDept)),
            ["fund"] = new("Fund", row => FormatCodeName(row.Fund)),
            ["account"] = new("Account", row => FormatCodeName(row.Account)),
            ["aeProject"] = new("AE Project", row => FormatCodeName(row.AeProject)),
            ["accountingPeriod"] = new("Accounting Period", row => row.AccountingPeriod),
            ["source"] = new("Source", row => row.Source),
            ["sfn"] = new("SFN", row => FormatCodeLabel(row.Sfn, row.SfnLabel)),
            ["amount"] = new("Amount", row => FormatDecimal(row.Amount, "0.00")),
            ["fte"] = new("FTE", row => FormatDecimal(row.Fte, "0.00")),
            ["included"] = new("Include State", row => row.Included ? "Included" : "Excluded"),
        };

    public static async Task WriteAsync(
        Stream output,
        IAsyncEnumerable<ExpenseReviewTransactionDto> rows,
        IReadOnlyList<string> columnIds,
        CancellationToken cancellationToken)
    {
        var columns = columnIds.Select(columnId => Columns[columnId]).ToList();
        await CsvExportWriter.WriteAsync(output, rows, columns, cancellationToken);
    }

    private static string? FormatCodeName(ExpenseReviewCodeNameDto value)
    {
        if (string.IsNullOrWhiteSpace(value.Code))
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(value.Name))
        {
            return value.Code;
        }

        return $"{value.Code} - {value.Name}";
    }

    private static string? FormatCodeLabel(string? code, string? label)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(label))
        {
            return code;
        }

        return $"{code} - {label}";
    }

    private static string? FormatDecimal(decimal? value, string format) =>
        value?.ToString(format, CultureInfo.InvariantCulture);

}
