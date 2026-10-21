using System.Text.Json;
using Server.Authorization;
using Server.Core.Data;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;
using UCDavis.CaesAi.AppSdk;

namespace Server.Assistant;

public sealed class ExpenseReviewToolDispatcher(
    IExpenseReviewService expenseReviewService,
    IConfirmedCycleProvider confirmedCycles,
    AppDbContext appDb,
    ILogger<ExpenseReviewToolDispatcher> logger) : ICaesAiToolDispatcher
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task<ToolExecutionResponse> ExecuteAsync(
        ToolExecutionRequest request,
        string userReference,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(userReference, out var entraId) ||
            !await AuthorizedUsers.IsAuthorizedAsync(appDb, entraId, cancellationToken))
        {
            return ToolExecutionResponse.Failure("unauthorized", "User is not authorized.");
        }

        var cycle = await confirmedCycles.GetAsync(cancellationToken);
        if (cycle is null)
        {
            return ToolExecutionResponse.Failure(
                "no_confirmed_cycle",
                "No fiscal period has been confirmed in Project Identification.");
        }

        try
        {
            return request.ToolName switch
            {
                ExpenseReviewToolManifest.FilterOptions => await FilterOptionsAsync(cycle, request.Arguments, cancellationToken),
                ExpenseReviewToolManifest.QueryTransactions => await QueryAsync(cycle, request.Arguments, cancellationToken),
                ExpenseReviewToolManifest.Summarize => await SummarizeAsync(cycle, request.Arguments, cancellationToken),
                _ => ToolExecutionResponse.Failure("unknown_tool", "The requested tool is not available."),
            };
        }
        catch (JsonException)
        {
            return ToolExecutionResponse.Failure("invalid_arguments", "The tool arguments are not valid JSON for this tool.");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Assistant tool {ToolName} failed for call {ToolCallId}", request.ToolName, request.ToolCallId);
            return ToolExecutionResponse.Failure("tool_failed", "The request could not be completed.", retryable: true);
        }
    }

    private async Task<ToolExecutionResponse> FilterOptionsAsync(
        FiscalYearCycle cycle,
        JsonElement arguments,
        CancellationToken cancellationToken)
    {
        var input = arguments.Deserialize<FilterOptionsArguments>(Json) ?? new FilterOptionsArguments();
        var hasCodes = input.Codes?.Length > 0;
        var hasSearch = !string.IsNullOrWhiteSpace(input.Search);

        if (input.Filter == null && (hasCodes || hasSearch))
        {
            return ToolExecutionResponse.Failure("invalid_arguments", "filter is required when search or codes is given.");
        }

        if (input.Filter != null && !ExpenseReviewToolManifest.FilterNames.Contains(input.Filter))
        {
            return ToolExecutionResponse.Failure(
                "invalid_arguments",
                $"filter must be one of: {string.Join(", ", ExpenseReviewToolManifest.FilterNames)}.");
        }

        var options = OptionsByFilter(await expenseReviewService.GetFilterOptionsAsync(cycle, cancellationToken));
        var display = new ToolDisplay("expense-review-filter-options", new { }, Visibility: CaesAiDisplayVisibility.Hidden);

        if (input.Filter == null)
        {
            var overview = new Dictionary<string, object>
            {
                ["fiscalYear"] = cycle.FiscalYear,
                ["cycleStart"] = cycle.CycleStart.ToString("yyyy-MM-dd"),
                ["cycleEnd"] = cycle.CycleEnd.ToString("yyyy-MM-dd"),
                ["searchOnlyCounts"] = ExpenseReviewToolManifest.SearchOnlyFilterNames
                    .ToDictionary(name => name, name => options[name].Count),
            };
            foreach (var name in ExpenseReviewToolManifest.ListedFilterNames)
            {
                overview[name] = Codes(options[name]);
            }

            return ToolExecutionResponse.Success(overview, display);
        }

        var values = options[input.Filter];
        string[] unknownCodes = [];
        List<ExpenseReviewFilterOptionDto> matched;

        if (hasCodes)
        {
            var requested = input.Codes!.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            var byCode = values.ToDictionary(option => option.Value, StringComparer.OrdinalIgnoreCase);
            matched = requested.Where(byCode.ContainsKey).Select(code => byCode[code]).ToList();
            unknownCodes = requested.Where(code => !byCode.ContainsKey(code)).ToArray();
        }
        else if (hasSearch)
        {
            matched = Search(values, input.Search!);
        }
        else
        {
            matched = values.ToList();
        }

        var limit = Math.Clamp(input.Limit ?? ExpenseReviewToolManifest.DefaultFilterOptionLimit, 1, ExpenseReviewToolManifest.MaxFilterOptionLimit);

        return ToolExecutionResponse.Success(
            new
            {
                fiscalYear = cycle.FiscalYear,
                cycleStart = cycle.CycleStart.ToString("yyyy-MM-dd"),
                cycleEnd = cycle.CycleEnd.ToString("yyyy-MM-dd"),
                filter = input.Filter,
                totalMatches = matched.Count,
                matches = Codes(matched.Take(limit).ToList()),
                unknownCodes,
            },
            display);

        static object[] Codes(IReadOnlyList<ExpenseReviewFilterOptionDto> items) =>
            items.Select(item => (object)new { code = item.Value, name = item.Label }).ToArray();
    }

    // Every word must appear in the code or the name. Exact code matches come first, then codes
    // that start with the search text, then everything else in the service's order.
    private static List<ExpenseReviewFilterOptionDto> Search(
        IReadOnlyList<ExpenseReviewFilterOptionDto> values,
        string search)
    {
        var text = search.Trim();
        var words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);

        return values
            .Where(option => words.All(word =>
                option.Value.Contains(word, StringComparison.OrdinalIgnoreCase) ||
                option.Label.Contains(word, StringComparison.OrdinalIgnoreCase)))
            .OrderBy(option =>
                option.Value.Equals(text, StringComparison.OrdinalIgnoreCase) ? 0 :
                option.Value.StartsWith(text, StringComparison.OrdinalIgnoreCase) ? 1 : 2)
            .ToList();
    }

    private static Dictionary<string, IReadOnlyList<ExpenseReviewFilterOptionDto>> OptionsByFilter(
        ExpenseReviewFilterOptionsResponse options) => new()
    {
        ["entity"] = options.Entities,
        ["financialDept"] = options.FinancialDepts,
        ["fund"] = options.Funds,
        ["account"] = options.Accounts,
        ["aeProject"] = options.AeProjects,
        ["accountingPeriod"] = options.AccountingPeriods,
        ["purpose"] = options.Purposes,
        ["program"] = options.Programs,
        ["activity"] = options.Activities,
        ["sfn"] = options.Sfns,
        ["source"] = options.Sources,
        ["exclusionReason"] = options.ExclusionReasons,
    };

    private async Task<ToolExecutionResponse> QueryAsync(FiscalYearCycle cycle, JsonElement arguments, CancellationToken cancellationToken)
    {
        var input = arguments.Deserialize<QueryArguments>(Json) ?? new QueryArguments();
        var query = ToQuery(
            input,
            input.Page ?? 1,
            Math.Clamp(input.PageSize ?? ExpenseReviewToolManifest.DefaultPageSize, 1, ExpenseReviewToolManifest.MaxPageSize),
            input.SortBy,
            input.SortDirection,
            input.DisplayByPeriod ?? false);

        if (!ExpenseReviewRequestParser.TryParse(query, out var request, out var error))
        {
            return ToolExecutionResponse.Failure("invalid_arguments", error!);
        }

        var response = await expenseReviewService.GetTransactionsAsync(cycle, request, cancellationToken);

        return ToolExecutionResponse.Success(new
        {
            fiscalYear = response.FiscalYear,
            cycleStart = response.CycleStart.ToString("yyyy-MM-dd"),
            cycleEnd = response.CycleEnd.ToString("yyyy-MM-dd"),
            counts = new { all = response.Counts.All, included = response.Counts.Included, excluded = response.Counts.Excluded },
            totalCount = response.TotalCount,
            totalAmount = response.TotalAmount,
            page = response.Page,
            pageSize = response.PageSize,
            pageCount = response.PageCount,
            columns = ExpenseReviewAssistantTable.Columns,
            rows = response.Rows.Select(ExpenseReviewAssistantTable.ToRow).ToArray(),
        });
    }

    private async Task<ToolExecutionResponse> SummarizeAsync(FiscalYearCycle cycle, JsonElement arguments, CancellationToken cancellationToken)
    {
        var input = arguments.Deserialize<SummaryArguments>(Json) ?? new SummaryArguments();
        if (input.GroupBy is null || !ExpenseReviewSummaryDimensions.IsValid(input.GroupBy))
        {
            return ToolExecutionResponse.Failure(
                "invalid_arguments",
                $"groupBy must be one of: {string.Join(", ", ExpenseReviewSummaryDimensions.All)}.");
        }

        var sortByRowCount = (input.SortBy ?? "amount") switch
        {
            "amount" => false,
            "rowCount" => true,
            _ => (bool?)null,
        };
        if (sortByRowCount is null)
        {
            return ToolExecutionResponse.Failure("invalid_arguments", "sortBy must be amount or rowCount.");
        }

        if (!ExpenseReviewRequestParser.TryParse(ToQuery(input, 1, 1), out var parsed, out var error))
        {
            return ToolExecutionResponse.Failure("invalid_arguments", error!);
        }

        var request = new ExpenseReviewSummaryRequest(
            parsed.IncludeState,
            parsed.IncludeZeroAmounts,
            parsed.Filters,
            input.GroupBy,
            Math.Clamp(input.Limit ?? ExpenseReviewToolManifest.DefaultSummaryLimit, 1, ExpenseReviewToolManifest.MaxSummaryLimit),
            sortByRowCount.Value);

        var response = await expenseReviewService.GetSummaryAsync(cycle, request, cancellationToken);

        return ToolExecutionResponse.Success(new
        {
            fiscalYear = response.FiscalYear,
            groupBy = response.GroupBy,
            totalCount = response.TotalCount,
            totalAmount = response.TotalAmount,
            groupCount = response.GroupCount,
            groups = response.Groups.Select(group => new { code = group.Code, name = group.Name, rowCount = group.RowCount, amount = group.Amount }).ToArray(),
        });
    }

    private static ExpenseReviewTransactionsQuery ToQuery(
        FilterArguments input,
        int page,
        int pageSize,
        string? sortBy = null,
        string? sortDirection = null,
        bool displayByPeriod = false) => new()
    {
        IncludeState = input.IncludeState,
        Page = page,
        PageSize = pageSize,
        SortBy = sortBy,
        SortDirection = sortDirection,
        DisplayByPeriod = displayByPeriod,
        IncludeZeroAmounts = input.IncludeZeroAmounts ?? false,
        Entity = input.Entity ?? [],
        FinancialDept = input.FinancialDept ?? [],
        Fund = input.Fund ?? [],
        Account = input.Account ?? [],
        AeProject = input.AeProject ?? [],
        AccountingPeriod = input.AccountingPeriod ?? [],
        Purpose = input.Purpose ?? [],
        Program = input.Program ?? [],
        Activity = input.Activity ?? [],
        Sfn = input.Sfn ?? [],
        Source = input.Source ?? [],
        ExclusionReason = input.ExclusionReason ?? [],
    };

    private record FilterArguments
    {
        public string[]? Entity { get; init; }
        public string[]? FinancialDept { get; init; }
        public string[]? Fund { get; init; }
        public string[]? Account { get; init; }
        public string[]? AeProject { get; init; }
        public string[]? AccountingPeriod { get; init; }
        public string[]? Purpose { get; init; }
        public string[]? Program { get; init; }
        public string[]? Activity { get; init; }
        public string[]? Sfn { get; init; }
        public string[]? Source { get; init; }
        public string[]? ExclusionReason { get; init; }
        public string? IncludeState { get; init; }
        public bool? IncludeZeroAmounts { get; init; }
    }

    private sealed record QueryArguments : FilterArguments
    {
        public bool? DisplayByPeriod { get; init; }
        public string? SortBy { get; init; }
        public string? SortDirection { get; init; }
        public int? Page { get; init; }
        public int? PageSize { get; init; }
    }

    private sealed record FilterOptionsArguments
    {
        public string? Filter { get; init; }
        public string? Search { get; init; }
        public string[]? Codes { get; init; }
        public int? Limit { get; init; }
    }

    private sealed record SummaryArguments : FilterArguments
    {
        public string? GroupBy { get; init; }
        public int? Limit { get; init; }
        public string? SortBy { get; init; }
    }
}
