namespace Server.Models.ExpenseReview;

public sealed class ExpenseReviewGroupTransactionsQuery : ExpenseReviewTransactionsQuery
{
    public ExpenseReviewGroupTransactionsQuery() { PageSize = 25; }
    public string? DetailSortBy { get; init; }
    public string? DetailSortDirection { get; init; }
    public string? Search { get; init; }
}

public sealed record ExpenseReviewGroupTransactionsRequest(
    string GroupId,
    ExpenseReviewTransactionsRequest Context,
    string SortBy,
    bool SortDescending,
    string? Search);

public sealed record ExpenseReviewGroupTransactionsResponse(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    ExpenseReviewTransactionDto Group,
    int TransactionCount,
    int MatchingCount,
    decimal MatchingAmount,
    int Page,
    int PageSize,
    int PageCount,
    IReadOnlyList<ExpenseReviewTransactionDetailDto> Rows);

public record ExpenseReviewTransactionDetailDto
{
    public required string Id { get; init; }
    public DateTime? TransactionDate { get; init; }
    public DateTime? UcEarnEndDate { get; init; }
    public string? TransactionId { get; init; }
    public string? AccountingPeriod { get; init; }
    public string? EmployeeId { get; init; }
    public string? EmployeeName { get; init; }
    public string? PositionNumber { get; init; }
    public string? ErnCode { get; init; }
    public string? ErnDescription { get; init; }
    public string? SalaryFringe { get; init; }
    public string? JobCode { get; init; }
    public decimal? Hours { get; init; }
    public decimal? CalculatedFte { get; init; }
    public string? AccountingSequenceNumber { get; init; }
    public string? JournalName { get; init; }
    public string? LineDescription { get; init; }
    public string? DocumentType { get; init; }
    public string? JournalReference { get; init; }
    public decimal? Amount { get; init; }
    // Employee details span chartfield groups; group details keep their existing header context.
    public string? Entity { get; init; }
    public string? FinancialDepartment { get; init; }
    public string? Fund { get; init; }
    public string? Account { get; init; }
    public string? Project { get; init; }
    public string? Purpose { get; init; }
    public string? Program { get; init; }
    public string? Activity { get; init; }
    public string? OrgR { get; init; }
    public string? ExpenseSfn { get; init; }
    public string? FteSfn { get; init; }
    public bool? ReportIncluded { get; init; }
    public decimal? ReportFteContribution { get; init; }
    public string? ReportStatus { get; init; }
    public IReadOnlyList<ExpenseReviewExclusionReasonDto> ExclusionReasons { get; init; } = [];
}

public static class ExpenseReviewGroupTransactionsParser
{
    public static readonly IReadOnlyDictionary<string, string> SortColumns =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["transactionDate"] = "TransactionDate",
            ["ucEarnEndDate"] = "UcEarnEndDate",
            ["transactionId"] = "TransactionId",
            ["accountingPeriod"] = "AccountingPeriodSort",
            ["employeeId"] = "EmployeeId",
            ["employeeName"] = "EmployeeName",
            ["positionNumber"] = "PositionNumber",
            ["ernCode"] = "ErnCode",
            ["salaryFringe"] = "SalaryFringe",
            ["jobCode"] = "JobCode",
            ["hours"] = "Hours",
            ["calculatedFte"] = "CalculatedFte",
            ["id"] = "Id",
            ["accountingSequenceNumber"] = "SequenceNumberSort",
            ["journalName"] = "JournalName",
            ["lineDescription"] = "LineDescription",
            ["documentType"] = "DocumentType",
            ["journalReference"] = "JournalReference",
            ["amount"] = "Amount",
        };

    public static bool TryParse(string groupId, ExpenseReviewGroupTransactionsQuery query,
        out ExpenseReviewGroupTransactionsRequest request, out string? error)
    {
        request = null!;
        error = null;
        if (groupId.Length != 64 || !groupId.All(char.IsAsciiHexDigit))
        {
            error = "groupId must be a 64-character hexadecimal group identifier.";
            return false;
        }
        if (!ExpenseReviewRequestParser.TryParse(query, out var context, out error)) return false;
        if (!ExpenseReviewDetailRequestParser.TryParse(context.Page, context.PageSize,
                query.DetailSortBy, query.DetailSortDirection, query.Search, SortColumns,
                out var sort, out var descending, out var search, out error)) return false;
        request = new(groupId.ToUpperInvariant(), context, sort, descending, search);
        return true;
    }
}
