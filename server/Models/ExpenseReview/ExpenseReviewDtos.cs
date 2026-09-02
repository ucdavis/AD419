using Microsoft.AspNetCore.Mvc;

namespace Server.Models.ExpenseReview;

public sealed class ExpenseReviewTransactionsQuery
{
    public string? IncludeState { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = 50;

    public string? SortBy { get; init; }

    public string? SortDirection { get; init; }

    public bool DisplayByPeriod { get; init; }

    [FromQuery(Name = "financialDept")]
    public string[] FinancialDept { get; init; } = [];

    public string[] Fund { get; init; } = [];

    public string[] Account { get; init; } = [];

    public string[] AeProject { get; init; } = [];

    public string[] AccountingPeriod { get; init; } = [];

    public string[] Entity { get; init; } = [];

    public string[] Purpose { get; init; } = [];

    public string[] Program { get; init; } = [];

    public string[] Activity { get; init; } = [];

    public string[] Sfn { get; init; } = [];

    public string[] Source { get; init; } = [];

    public string[] ExclusionReason { get; init; } = [];
}

public sealed record ExpenseReviewTransactionsRequest(
    ExpenseReviewIncludeState IncludeState,
    int Page,
    int PageSize,
    string SortBy,
    bool SortDescending,
    bool DisplayByPeriod,
    ExpenseReviewFilters Filters);

public enum ExpenseReviewIncludeState
{
    All,
    Included,
    Excluded,
}

public sealed record ExpenseReviewFilters(
    IReadOnlyList<string> Entity,
    IReadOnlyList<string> FinancialDept,
    IReadOnlyList<string> Fund,
    IReadOnlyList<string> Account,
    IReadOnlyList<string> AeProject,
    IReadOnlyList<string> AccountingPeriod,
    IReadOnlyList<string> Purpose,
    IReadOnlyList<string> Program,
    IReadOnlyList<string> Activity,
    IReadOnlyList<string> Sfn,
    IReadOnlyList<string> Source,
    IReadOnlyList<string> ExclusionReason);

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
    string Source,
    ExpenseReviewCodeNameDto Entity,
    ExpenseReviewCodeNameDto FinancialDept,
    ExpenseReviewCodeNameDto Fund,
    ExpenseReviewCodeNameDto Account,
    ExpenseReviewCodeNameDto AeProject,
    string? AccountingPeriod,
    ExpenseReviewCodeNameDto Purpose,
    ExpenseReviewCodeNameDto Program,
    ExpenseReviewCodeNameDto Activity,
    string? Sfn,
    string? SfnLabel,
    decimal? Amount,
    bool Included,
    IReadOnlyList<ExpenseReviewExclusionReasonDto> ExclusionReasons);

public sealed record ExpenseReviewExclusionReasonDto(
    string Code,
    string Label,
    int RowCount,
    decimal Amount);

public sealed record ExpenseReviewCodeNameDto(
    string? Code,
    string? Name);

public sealed record ExpenseReviewFilterOptionsResponse(
    IReadOnlyList<ExpenseReviewFilterOptionDto> Entities,
    IReadOnlyList<ExpenseReviewFilterOptionDto> FinancialDepts,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Funds,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Accounts,
    IReadOnlyList<ExpenseReviewFilterOptionDto> AeProjects,
    IReadOnlyList<ExpenseReviewFilterOptionDto> AccountingPeriods,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Purposes,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Programs,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Activities,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Sfns,
    IReadOnlyList<ExpenseReviewFilterOptionDto> Sources,
    IReadOnlyList<ExpenseReviewFilterOptionDto> ExclusionReasons);

public sealed record ExpenseReviewFilterOptionDto(
    string Value,
    string Label);

public static class ExpenseReviewRequestParser
{
    public const int MaxPageSize = 500;
    public const string DefaultSortBy = "source";

    private static readonly HashSet<string> SortFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "accountingPeriod",
        "entity",
        "financialDept",
        "fund",
        "account",
        "aeProject",
        "purpose",
        "program",
        "activity",
        "sfn",
        "source",
        "amount",
        "included",
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
            query.DisplayByPeriod,
            new ExpenseReviewFilters(
                Clean(query.Entity),
                Clean(query.FinancialDept),
                Clean(query.Fund),
                Clean(query.Account),
                Clean(query.AeProject),
                Clean(query.AccountingPeriod),
                Clean(query.Purpose),
                Clean(query.Program),
                Clean(query.Activity),
                Clean(query.Sfn),
                Clean(query.Source).Select(source => source.ToUpperInvariant()).ToArray(),
                Clean(query.ExclusionReason)));
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
