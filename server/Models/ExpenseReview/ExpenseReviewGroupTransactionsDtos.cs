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
    public string? AccountingPeriod { get; init; }
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
    public IReadOnlyList<ExpenseReviewExclusionReasonDto> ExclusionReasons { get; init; } = [];
}

public static class ExpenseReviewGroupTransactionsParser
{
    public static readonly IReadOnlyDictionary<string, string> SortColumns =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["transactionDate"] = "TransactionDate",
            ["accountingPeriod"] = "AccountingPeriodSort",
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
        if ((long)(context.Page - 1) * context.PageSize > int.MaxValue)
        {
            error = "page exceeds the supported range.";
            return false;
        }
        var sort = string.IsNullOrWhiteSpace(query.DetailSortBy) ? "transactionDate" : query.DetailSortBy.Trim();
        if (!SortColumns.ContainsKey(sort))
        {
            error = "detailSortBy is not a supported transaction column.";
            return false;
        }
        var direction = query.DetailSortDirection?.Trim() ?? "asc";
        if (!direction.Equals("asc", StringComparison.OrdinalIgnoreCase) &&
            !direction.Equals("desc", StringComparison.OrdinalIgnoreCase))
        {
            error = "detailSortDirection must be asc or desc.";
            return false;
        }
        if (query.Search?.Length > 500)
        {
            error = "search must be at most 500 characters.";
            return false;
        }
        request = new(groupId.ToUpperInvariant(), context, sort,
            direction.Equals("desc", StringComparison.OrdinalIgnoreCase),
            string.IsNullOrWhiteSpace(query.Search) ? null : query.Search.Trim());
        return true;
    }
}
