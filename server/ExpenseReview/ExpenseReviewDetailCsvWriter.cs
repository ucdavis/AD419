using System.Globalization;
using Server.Exports;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public static class ExpenseReviewDetailCsvWriter
{
    public static Task WriteAsync(Stream output, IAsyncEnumerable<ExpenseReviewTransactionDetailDto> rows,
        FiscalYearCycle cycle, ExpenseReviewTransactionDto group, CancellationToken cancellationToken)
    {
        List<CsvExportColumn<ExpenseReviewTransactionDetailDto>> columns =
        [
            new("Source", _ => group.Source),
            new("Fiscal Year", _ => cycle.FiscalYear),
            new("Group ID", _ => group.Id),
            new("Entity", _ => CodeName(group.Entity)),
            new("Financial Dept", _ => CodeName(group.FinancialDept)),
            new("Fund", _ => CodeName(group.Fund)),
            new("Account", _ => CodeName(group.Account)),
            new("Project", _ => CodeName(group.AeProject)),
            new("Purpose", _ => CodeName(group.Purpose)),
            new("Program", _ => CodeName(group.Program)),
            new("Activity", _ => CodeName(group.Activity)),
            new("SFN", _ => group.Sfn),
            new("SFN Label", _ => group.SfnLabel),
            new("Include State", _ => group.Included ? "Included" : "Excluded"),
            new(group.Source == "UCP" ? "Pay-period end date" : "Journal accounting date", row => row.TransactionDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)),
            new("Accounting period", row => row.AccountingPeriod),
        ];
        if (group.Source == "UCP")
        {
            columns.AddRange([
                new("Employee name", row => row.EmployeeName),
                new("Position number", row => row.PositionNumber),
                new("Earnings code", row => row.ErnCode),
                new("Earnings description", row => row.ErnDescription),
                new("Salary/fringe", row => row.SalaryFringe),
                new("Job code", row => row.JobCode),
                new("Hours", row => Number(row.Hours)),
                new("Calculated FTE", row => Number(row.CalculatedFte)),
                new("Labor transaction ID", row => row.Id),
            ]);
        }
        else
        {
            columns.AddRange([
                new("Accounting sequence number", row => row.AccountingSequenceNumber),
                new("Journal name", row => row.JournalName),
                new("Line description", row => row.LineDescription),
                new("Document type", row => row.DocumentType),
                new("Journal reference", row => row.JournalReference),
                new("Transaction ID", row => row.Id),
            ]);
        }
        columns.Add(new("Amount", row => Number(row.Amount)));
        columns.Add(new("Exclusion reasons", row => string.Join("; ", row.ExclusionReasons.Select(reason => reason.Label))));
        return CsvExportWriter.WriteAsync(output, rows, columns, cancellationToken);
    }

    private static string? Number(decimal? value) => value?.ToString(CultureInfo.InvariantCulture);
    private static string? CodeName(ExpenseReviewCodeNameDto value) =>
        value.Name is null ? value.Code : $"{value.Code} - {value.Name}";
}
