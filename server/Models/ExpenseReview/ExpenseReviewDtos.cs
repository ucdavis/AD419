using Microsoft.AspNetCore.Mvc;

namespace Server.Models.ExpenseReview;

public sealed class ExpenseReviewTransactionsQuery
{
    public string? IncludeState { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = 50;

    public string? SortBy { get; init; }

    public string? SortDirection { get; init; }

    [FromQuery(Name = "financialDept")]
    public string[] FinancialDept { get; init; } = [];

    public string[] Fund { get; init; } = [];

    public string[] Account { get; init; } = [];

    public string[] AeProject { get; init; } = [];

    public string[] AccountingPeriod { get; init; } = [];

    public string[] Source { get; init; } = [];

    public string[] Sfn { get; init; } = [];
}

public sealed record ExpenseReviewTransactionsRequest(
    ExpenseReviewIncludeState IncludeState,
    int Page,
    int PageSize,
    string SortBy,
    bool SortDescending,
    ExpenseReviewFilters Filters);

public enum ExpenseReviewIncludeState
{
    All,
    Included,
    Excluded,
}

public sealed record ExpenseReviewFilters(
    IReadOnlyList<string> FinancialDept,
    IReadOnlyList<string> Fund,
    IReadOnlyList<string> Account,
    IReadOnlyList<string> AeProject,
    IReadOnlyList<string> AccountingPeriod,
    IReadOnlyList<string> Source,
    IReadOnlyList<string> Sfn);

public sealed record ExpenseReviewTransactionsResponse(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    ExpenseReviewCountsDto Counts,
    int TotalCount,
    int Page,
    int PageSize,
    int PageCount,
    IReadOnlyList<ExpenseReviewTransactionDto> Rows);

public sealed record ExpenseReviewCountsDto(
    int All,
    int Included,
    int Excluded);

public sealed record ExpenseReviewTransactionDto(
    string Id,
    string SourceId,
    string Source,
    ExpenseReviewCodeNameDto FinancialDept,
    ExpenseReviewCodeNameDto Fund,
    ExpenseReviewCodeNameDto Account,
    ExpenseReviewCodeNameDto AeProject,
    string? AccountingPeriod,
    string? Sfn,
    string? SfnLabel,
    decimal? Amount,
    decimal? Fte,
    bool FteIncluded,
    bool Included);

public sealed record ExpenseReviewCodeNameDto(
    string? Code,
    string? Name);

public sealed record ExpenseReviewFilterOptionsResponse(
    IReadOnlyList<ExpenseReviewFilterOptionDto> FinancialDepts,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Funds,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Accounts,
    IReadOnlyList<ExpenseReviewFilterOptionDto> AeProjects,
    IReadOnlyList<ExpenseReviewFilterOptionDto> AccountingPeriods,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Sources,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Sfns);

public sealed record ExpenseReviewFilterOptionDto(
    string Value,
    string Label);

public static class ExpenseReviewRequestParser
{
    public const int MaxPageSize = 500;
    public const string DefaultSortBy = "source";

    private static readonly HashSet<string> SortFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "financialDept",
        "fund",
        "account",
        "aeProject",
        "accountingPeriod",
        "source",
        "sfn",
        "amount",
        "fte",
    };

    public static bool TryParse(
        ExpenseReviewTransactionsQuery query,
        out ExpenseReviewTransactionsRequest request,
        out string? error)
    {
        request = null!;
        error = null;

        if (query.Page < 1)
        {
            error = "page must be greater than or equal to 1.";
            return false;
        }

        if (query.PageSize is < 1 or > MaxPageSize)
        {
            error = $"pageSize must be between 1 and {MaxPageSize}.";
            return false;
        }

        if (!TryParseIncludeState(query.IncludeState, out var includeState))
        {
            error = "includeState must be all, included, or excluded.";
            return false;
        }

        var sortBy = string.IsNullOrWhiteSpace(query.SortBy)
            ? DefaultSortBy
            : query.SortBy.Trim();
        if (!SortFields.Contains(sortBy))
        {
            error = $"sortBy must be one of: {string.Join(", ", SortFields.Order(StringComparer.Ordinal))}.";
            return false;
        }

        if (!TryParseSortDirection(query.SortDirection, out var sortDescending))
        {
            error = "sortDirection must be asc or desc.";
            return false;
        }

        request = new ExpenseReviewTransactionsRequest(
            includeState,
            query.Page,
            query.PageSize,
            sortBy,
            sortDescending,
            new ExpenseReviewFilters(
                Clean(query.FinancialDept),
                Clean(query.Fund),
                Clean(query.Account),
                Clean(query.AeProject),
                Clean(query.AccountingPeriod),
                Clean(query.Source).Select(source => source.ToUpperInvariant()).ToArray(),
                Clean(query.Sfn)));
        return true;
    }

    public static bool IsAllowedSortField(string value) => SortFields.Contains(value);

    private static bool TryParseIncludeState(string? value, out ExpenseReviewIncludeState includeState)
    {
        includeState = ExpenseReviewIncludeState.All;
        if (string.IsNullOrWhiteSpace(value) || value.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (value.Equals("included", StringComparison.OrdinalIgnoreCase))
        {
            includeState = ExpenseReviewIncludeState.Included;
            return true;
        }

        if (value.Equals("excluded", StringComparison.OrdinalIgnoreCase))
        {
            includeState = ExpenseReviewIncludeState.Excluded;
            return true;
        }

        return false;
    }

    private static bool TryParseSortDirection(string? value, out bool sortDescending)
    {
        sortDescending = false;
        if (string.IsNullOrWhiteSpace(value) || value.Equals("asc", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (value.Equals("desc", StringComparison.OrdinalIgnoreCase))
        {
            sortDescending = true;
            return true;
        }

        return false;
    }

    private static string[] Clean(IEnumerable<string>? values) =>
        values?
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray() ?? [];
}
