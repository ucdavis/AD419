using System.Globalization;
using Server.Exports;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public static class ExpenseReviewCsvWriter
{
    private static readonly CsvExportColumn<ExpenseReviewTransactionDto> SourceColumn =
        new("Source", row => row.Source);

    private static readonly IReadOnlyList<CsvExportColumn<ExpenseReviewTransactionDto>> DefaultColumns =
    [
        SourceColumn,
        new("Entity", row => FormatCodeName(row.Entity)),
        new("Fund", row => FormatCodeName(row.Fund)),
        new("Financial Dept", row => FormatCodeName(row.FinancialDept)),
        new("Account", row => FormatCodeName(row.Account)),
        new("Purpose", row => FormatCodeName(row.Purpose)),
        new("Program", row => FormatCodeName(row.Program)),
        new("Project", row => FormatCodeName(row.AeProject)),
        new("Activity", row => FormatCodeName(row.Activity)),
        new("SFN", row => FormatCodeLabel(row.Sfn, row.SfnLabel)),
        new("Amount", row => FormatDecimal(row.Amount, "0.00")),
        new("Include State", row => row.Included ? "Included" : "Excluded"),
        new("Exclusion Reasons", FormatReasons),
    ];

    private static readonly IReadOnlyList<CsvExportColumn<ExpenseReviewTransactionDto>> PeriodColumns =
    [
        SourceColumn,
        new("Accounting Period", row => row.AccountingPeriod),
        .. DefaultColumns.Skip(1),
    ];

    public static async Task WriteAsync(
        Stream output,
        IAsyncEnumerable<ExpenseReviewTransactionDto> rows,
        bool displayByPeriod,
        CancellationToken cancellationToken)
    {
        var columns = displayByPeriod ? PeriodColumns : DefaultColumns;
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

    private static string? FormatReasons(ExpenseReviewTransactionDto row)
    {
        if (row.ExclusionReasons.Count == 0)
        {
            return null;
        }

        return string.Join("; ", row.ExclusionReasons.Select(reason =>
            $"{reason.Label} · {FormatCurrency(reason.Amount)} · {FormatRowCount(reason.RowCount)}"));
    }

    private static string FormatRowCount(int rowCount) =>
        rowCount == 1 ? "1 row" : $"{rowCount} rows";

    private static string FormatCurrency(decimal value) =>
        value.ToString("C2", CultureInfo.GetCultureInfo("en-US"));

    private static string? FormatDecimal(decimal? value, string format) =>
        value?.ToString(format, CultureInfo.InvariantCulture);
}
