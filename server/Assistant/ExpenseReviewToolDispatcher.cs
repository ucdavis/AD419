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
                ExpenseReviewToolManifest.FilterOptions => await FilterOptionsAsync(cycle, cancellationToken),
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

    private async Task<ToolExecutionResponse> FilterOptionsAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        var options = await expenseReviewService.GetFilterOptionsAsync(cycle, cancellationToken);

        return ToolExecutionResponse.Success(
            new
            {
                fiscalYear = cycle.FiscalYear,
                cycleStart = cycle.CycleStart.ToString("yyyy-MM-dd"),
                cycleEnd = cycle.CycleEnd.ToString("yyyy-MM-dd"),
                entity = Codes(options.Entities),
                financialDept = Codes(options.FinancialDepts),
                fund = Codes(options.Funds),
                account = Codes(options.Accounts),
                aeProject = Codes(options.AeProjects),
                accountingPeriod = Codes(options.AccountingPeriods),
                purpose = Codes(options.Purposes),
                program = Codes(options.Programs),
                activity = Codes(options.Activities),
                sfn = Codes(options.Sfns),
                source = Codes(options.Sources),
                exclusionReason = Codes(options.ExclusionReasons),
            },
            new ToolDisplay("expense-review-filter-options", new { }, Visibility: CaesAiDisplayVisibility.Hidden));

        static object[] Codes(IReadOnlyList<ExpenseReviewFilterOptionDto> items) =>
            items.Select(item => (object)new { code = item.Value, name = item.Label }).ToArray();
    }

    private async Task<ToolExecutionResponse> QueryAsync(FiscalYearCycle cycle, JsonElement arguments, CancellationToken cancellationToken)
    {
        var input = arguments.Deserialize<QueryArguments>(Json) ?? new QueryArguments();
        var query = ToQuery(
            input,
            input.Page ?? 1,
            Math.Min(input.PageSize ?? ExpenseReviewToolManifest.DefaultPageSize, ExpenseReviewToolManifest.MaxPageSize),
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

    private sealed record SummaryArguments : FilterArguments
    {
        public string? GroupBy { get; init; }
        public int? Limit { get; init; }
        public string? SortBy { get; init; }
    }
}
