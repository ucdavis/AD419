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
            new("Entity", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Entity)),
            new("Financial Dept", _ => ExpenseReviewCsvWriter.FormatCodeName(group.FinancialDept)),
            new("Fund", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Fund)),
            new("Account", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Account)),
            new("Project", _ => ExpenseReviewCsvWriter.FormatCodeName(group.AeProject)),
            new("Purpose", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Purpose)),
            new("Program", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Program)),
            new("Activity", _ => ExpenseReviewCsvWriter.FormatCodeName(group.Activity)),
            new("SFN", _ => group.Sfn),
            new("SFN Label", _ => group.SfnLabel),
            new("Include State", _ => group.Included ? "Included" : "Excluded"),
        ];
        columns.AddRange(DetailColumns(group.Source));
        return CsvExportWriter.WriteAsync(output, rows, columns, cancellationToken);
    }

    public static Task WriteEmployeeAsync(Stream output, IAsyncEnumerable<ExpenseReviewTransactionDetailDto> rows,
        FiscalYearCycle cycle, ExpenseReviewEmployeeTransactionsResponse employee, CancellationToken cancellationToken)
    {
        List<CsvExportColumn<ExpenseReviewTransactionDetailDto>> columns =
        [
            new("Source", _ => "UCP"),
            new("Fiscal Year", _ => cycle.FiscalYear),
            new("Scope", _ => employee.Scope),
            new("Report FTE", _ => Number(employee.ReportFte)),
            new("Entity", row => row.Entity),
            new("Financial Dept", row => row.FinancialDepartment),
            new("Fund", row => row.Fund),
            new("Account", row => row.Account),
            new("Project", row => row.Project),
            new("Purpose", row => row.Purpose),
            new("Program", row => row.Program),
            new("Activity", row => row.Activity),
            new("OrgR", row => row.OrgR),
            new("SFN", row => row.ExpenseSfn),
            new("FTE SFN", row => row.FteSfn),
            new("Report status", row => row.ReportStatus),
            new("Report FTE contribution", row => Number(row.ReportFteContribution)),
        ];
        columns.AddRange(DetailColumns("UCP"));
        return CsvExportWriter.WriteAsync(output, rows, columns, cancellationToken);
    }

    private static IReadOnlyList<CsvExportColumn<ExpenseReviewTransactionDetailDto>> DetailColumns(string source)
    {
        List<CsvExportColumn<ExpenseReviewTransactionDetailDto>> columns =
        [
            new(source == "UCP" ? "Pay End Date" : "Journal accounting date", row => Date(row.TransactionDate)),
        ];
        if (source == "UCP")
            columns.Add(new("UC Earn End Date", row => Date(row.UcEarnEndDate)));
        columns.Add(new("Accounting period", row => row.AccountingPeriod));
        if (source == "UCP")
        {
            columns.AddRange([
                new("Employee ID", row => row.EmployeeId),
                new("Employee name", row => row.EmployeeName),
                new("Transaction ID", row => row.TransactionId),
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
        return columns;
    }

    private static string? Date(DateTime? value) => value?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    private static string? Number(decimal? value) => value?.ToString(CultureInfo.InvariantCulture);
}
