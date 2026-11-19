namespace Server.Models.ExpenseReview;

public sealed class ExpenseReviewEmployeeTransactionsQuery
{
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 25;
    public string? DetailSortBy { get; init; }
    public string? DetailSortDirection { get; init; }
    public string? Search { get; init; }
    public string? Scope { get; init; }
}

public sealed record ExpenseReviewEmployeeTransactionsRequest(
    string EmployeeId, string Scope, int Page, int PageSize,
    string SortBy, bool SortDescending, string? Search);

public sealed record ExpenseReviewEmployeeTransactionsResponse(
    string FiscalYear, DateOnly CycleStart, DateOnly CycleEnd,
    string EmployeeId, string? EmployeeName, decimal ReportFte, string Scope,
    int TransactionCount, decimal TotalAmount, int MatchingCount, decimal MatchingAmount,
    int Page, int PageSize, int PageCount, IReadOnlyList<ExpenseReviewTransactionDetailDto> Rows);

public sealed record ExpenseReviewEmployeeTransactionsResult(
    bool BuildAvailable, ExpenseReviewEmployeeTransactionsResponse? Response);

public static class ExpenseReviewEmployeeTransactionsParser
{
    public static readonly IReadOnlyDictionary<string, string> SortColumns =
        new Dictionary<string, string>(ExpenseReviewGroupTransactionsParser.SortColumns, StringComparer.OrdinalIgnoreCase)
        {
            ["entity"] = "Entity",
            ["financialDepartment"] = "FinancialDepartment",
            ["fund"] = "Fund",
            ["account"] = "Account",
            ["project"] = "Project",
            ["purpose"] = "Purpose",
            ["program"] = "Program",
            ["activity"] = "Activity",
            ["orgR"] = "OrgR",
            ["expenseSfn"] = "ExpenseSfn",
            ["fteSfn"] = "FteSfn",
            ["reportFteContribution"] = "ReportFteContribution",
            ["reportStatus"] = "ReportStatus",
        };

    public static bool TryParse(string employeeId, ExpenseReviewEmployeeTransactionsQuery query,
        out ExpenseReviewEmployeeTransactionsRequest request, out string? error)
    {
        request = null!;
        error = null;
        if (string.IsNullOrWhiteSpace(employeeId) || employeeId.Trim().Length > 10)
        {
            error = "employeeId must contain between 1 and 10 characters.";
            return false;
        }
        var scope = query.Scope?.Trim().ToLowerInvariant() ?? "report";
        if (scope != "report" && scope != "all")
        {
            error = "scope must be report or all.";
            return false;
        }
        if (!ExpenseReviewDetailRequestParser.TryParse(query.Page, query.PageSize,
                query.DetailSortBy, query.DetailSortDirection, query.Search, SortColumns,
                out var sort, out var descending, out var search, out error)) return false;
        request = new(employeeId.Trim(), scope, query.Page, query.PageSize, sort, descending, search);
        return true;
    }
}

internal static class ExpenseReviewDetailRequestParser
{
    internal static bool TryParse(int page, int pageSize, string? sortBy, string? sortDirection,
        string? searchText, IReadOnlyDictionary<string, string> columns,
        out string sort, out bool descending, out string? search, out string? error)
    {
        sort = string.IsNullOrWhiteSpace(sortBy) ? "transactionDate" : sortBy.Trim();
        descending = false;
        search = string.IsNullOrWhiteSpace(searchText) ? null : searchText.Trim();
        error = null;
        if (page < 1)
            error = "page must be greater than or equal to 1.";
        else if (pageSize < 1 || pageSize > ExpenseReviewRequestParser.MaxPageSize)
            error = $"pageSize must be between 1 and {ExpenseReviewRequestParser.MaxPageSize}.";
        else if ((long)(page - 1) * pageSize > int.MaxValue)
            error = "page exceeds the supported range.";
        else if (!columns.ContainsKey(sort))
            error = "detailSortBy is not a supported transaction column.";
        else if (searchText?.Length > 500)
            error = "search must be at most 500 characters.";
        if (error != null) return false;

        var direction = sortDirection?.Trim() ?? "asc";
        if (!direction.Equals("asc", StringComparison.OrdinalIgnoreCase) &&
            !direction.Equals("desc", StringComparison.OrdinalIgnoreCase))
        {
            error = "detailSortDirection must be asc or desc.";
            return false;
        }
        descending = direction.Equals("desc", StringComparison.OrdinalIgnoreCase);
        return true;
    }
}
