using System.Text.Json.Nodes;
using Server.Models.ExpenseReview;
using UCDavis.CaesAi.AppSdk;

namespace Server.Assistant;

public static class ExpenseReviewToolManifest
{
    public const string FilterOptions = "get_expense_review_filter_options";
    public const string QueryTransactions = "query_expense_review_transactions";
    public const string Summarize = "summarize_expense_review_transactions";
    public const string GetView = "get_expense_review_view";
    public const string SetFilters = "set_expense_review_filters";

    public const int MaxPageSize = 100;
    public const int DefaultPageSize = 25;
    public const int MaxSummaryLimit = 500;
    public const int DefaultSummaryLimit = 100;

    public static readonly IReadOnlyList<string> FilterNames =
    [
        "entity",
        "financialDept",
        "fund",
        "account",
        "aeProject",
        "accountingPeriod",
        "purpose",
        "program",
        "activity",
        "sfn",
        "source",
        "exclusionReason",
    ];

    private static readonly string[] SortFields =
    [
        "accountingPeriod", "entity", "financialDept", "fund", "account", "aeProject",
        "purpose", "program", "activity", "sfn", "source", "amount", "included",
    ];

    public static IReadOnlyList<ApplicationToolManifest> Build() =>
    [
        new(
            FilterOptions,
            "Returns the confirmed fiscal cycle and every valid filter value for the Expense Review table: " +
            "entity, financialDept, fund, account, aeProject, accountingPeriod, purpose, program, activity, sfn, source, and exclusionReason, " +
            "each as {code, name}. Call this before filtering or summarizing so you use real codes, and to translate codes into names.",
            CaesAiToolExecution.Server,
            CaesAiToolRisk.Read,
            false,
            CaesAiJsonSchema.Object(new JsonObject()),
            FilterOptionsDataSchema(),
            new ToolPresentation("expense-review-filter-options", "Filter options")),
        new(
            QueryTransactions,
            "Returns one page of grouped Expense Review rows for a filter set as a columnar table, plus counts and the total amount of the whole filtered set. " +
            "Rows contain codes only; use get_expense_review_filter_options to translate codes to names. " +
            "Use this to show examples or a specific short list. For totals or comparisons across a dimension use summarize_expense_review_transactions instead of paging.",
            CaesAiToolExecution.Server,
            CaesAiToolRisk.Read,
            false,
            QueryInputSchema(),
            QueryDataSchema()),
        new(
            Summarize,
            "Aggregates the filtered Expense Review rows by one dimension and returns row count and amount per group, sorted descending, " +
            "plus the total count and amount and how many groups exist in all. Prefer this for any question about how much, how many, or which groups are largest. " +
            "When groupBy is exclusionReason, a transaction is counted once per reason it carries, rowCount counts transactions rather than grouped rows, and group counts and amounts can sum to more than totalCount and totalAmount. " +
            "When groupBy is accountingPeriod, totalCount counts period-split rows.",
            CaesAiToolExecution.Server,
            CaesAiToolRisk.Read,
            false,
            SummaryInputSchema(),
            SummaryDataSchema()),
        new(
            GetView,
            "Returns the filters, include state, sort, paging, and toggles currently applied on the user's Expense Review page.",
            CaesAiToolExecution.Client,
            CaesAiToolRisk.Read,
            false,
            CaesAiJsonSchema.Object(new JsonObject()),
            ViewDataSchema()),
        new(
            SetFilters,
            "Replaces the filters and include state on the user's Expense Review page and returns to page 1. " +
            "Omitted filter arrays are cleared. Use this when the user asks to see, show, or filter rows on screen.",
            CaesAiToolExecution.Client,
            CaesAiToolRisk.Read,
            false,
            SetFiltersInputSchema(),
            CaesAiJsonSchema.Object(new JsonObject
            {
                ["applied"] = new JsonObject { ["type"] = "boolean" },
                ["filters"] = FiltersSchema(),
                ["includeState"] = IncludeStateSchema(),
            }, "applied", "filters", "includeState")),
    ];

    private static JsonObject StringArray() => new()
    {
        ["type"] = "array",
        ["items"] = CaesAiJsonSchema.String(),
    };

    private static JsonObject IncludeStateSchema() => CaesAiJsonSchema.String("all", "included", "excluded");

    private static JsonObject FiltersSchema() => CaesAiJsonSchema.Object(FilterProperties(), FilterNames.ToArray());

    private static JsonObject FilterProperties()
    {
        var properties = new JsonObject();
        foreach (var name in FilterNames)
        {
            properties[name] = StringArray();
        }

        return properties;
    }

    private static JsonObject QueryInputSchema()
    {
        var properties = FilterProperties();
        properties["includeState"] = IncludeStateSchema();
        properties["includeZeroAmounts"] = new JsonObject { ["type"] = "boolean" };
        properties["displayByPeriod"] = new JsonObject { ["type"] = "boolean" };
        properties["sortBy"] = CaesAiJsonSchema.String(SortFields);
        properties["sortDirection"] = CaesAiJsonSchema.String("asc", "desc");
        properties["page"] = CaesAiJsonSchema.Integer(1);
        properties["pageSize"] = new JsonObject { ["type"] = "integer", ["minimum"] = 1, ["maximum"] = MaxPageSize };
        return CaesAiJsonSchema.Object(properties);
    }

    private static JsonObject QueryDataSchema() => CaesAiJsonSchema.Object(new JsonObject
    {
        ["fiscalYear"] = CaesAiJsonSchema.String(),
        ["cycleStart"] = CaesAiJsonSchema.String(),
        ["cycleEnd"] = CaesAiJsonSchema.String(),
        ["counts"] = CaesAiJsonSchema.Object(new JsonObject
        {
            ["all"] = CaesAiJsonSchema.Integer(),
            ["included"] = CaesAiJsonSchema.Integer(),
            ["excluded"] = CaesAiJsonSchema.Integer(),
        }, "all", "included", "excluded"),
        ["totalCount"] = CaesAiJsonSchema.Integer(),
        ["totalAmount"] = new JsonObject { ["type"] = "number" },
        ["page"] = CaesAiJsonSchema.Integer(1),
        ["pageSize"] = CaesAiJsonSchema.Integer(1),
        ["pageCount"] = CaesAiJsonSchema.Integer(),
        ["columns"] = StringArray(),
        ["rows"] = new JsonObject
        {
            ["type"] = "array",
            ["items"] = new JsonObject { ["type"] = "array" },
        },
    }, "fiscalYear", "cycleStart", "cycleEnd", "counts", "totalCount", "totalAmount", "page", "pageSize", "pageCount", "columns", "rows");

    private static JsonObject SummaryInputSchema()
    {
        var properties = FilterProperties();
        properties["includeState"] = IncludeStateSchema();
        properties["includeZeroAmounts"] = new JsonObject { ["type"] = "boolean" };
        properties["groupBy"] = CaesAiJsonSchema.String(ExpenseReviewSummaryDimensions.All.ToArray());
        properties["limit"] = new JsonObject { ["type"] = "integer", ["minimum"] = 1, ["maximum"] = MaxSummaryLimit };
        properties["sortBy"] = CaesAiJsonSchema.String("amount", "rowCount");
        return CaesAiJsonSchema.Object(properties, "groupBy");
    }

    private static JsonObject SummaryDataSchema() => CaesAiJsonSchema.Object(new JsonObject
    {
        ["fiscalYear"] = CaesAiJsonSchema.String(),
        ["groupBy"] = CaesAiJsonSchema.String(),
        ["totalCount"] = CaesAiJsonSchema.Integer(),
        ["totalAmount"] = new JsonObject { ["type"] = "number" },
        ["groupCount"] = CaesAiJsonSchema.Integer(),
        ["groups"] = new JsonObject
        {
            ["type"] = "array",
            ["items"] = CaesAiJsonSchema.Object(new JsonObject
            {
                ["code"] = new JsonObject { ["type"] = CaesAiJsonSchema.NullableTypes("string") },
                ["name"] = new JsonObject { ["type"] = CaesAiJsonSchema.NullableTypes("string") },
                ["rowCount"] = CaesAiJsonSchema.Integer(),
                ["amount"] = new JsonObject { ["type"] = "number" },
            }, "code", "name", "rowCount", "amount"),
        },
    }, "fiscalYear", "groupBy", "totalCount", "totalAmount", "groupCount", "groups");

    private static JsonObject FilterOptionsDataSchema()
    {
        var option = CaesAiJsonSchema.Object(new JsonObject
        {
            ["code"] = CaesAiJsonSchema.String(),
            ["name"] = CaesAiJsonSchema.String(),
        }, "code", "name");
        var properties = new JsonObject
        {
            ["fiscalYear"] = CaesAiJsonSchema.String(),
            ["cycleStart"] = CaesAiJsonSchema.String(),
            ["cycleEnd"] = CaesAiJsonSchema.String(),
        };
        foreach (var name in FilterNames)
        {
            properties[name] = new JsonObject { ["type"] = "array", ["items"] = option.DeepClone() };
        }

        return CaesAiJsonSchema.Object(properties, ["fiscalYear", "cycleStart", "cycleEnd", .. FilterNames]);
    }

    private static JsonObject ViewDataSchema() => CaesAiJsonSchema.Object(new JsonObject
    {
        ["filters"] = FiltersSchema(),
        ["includeState"] = IncludeStateSchema(),
        ["sortBy"] = CaesAiJsonSchema.String(SortFields),
        ["sortDirection"] = CaesAiJsonSchema.String("asc", "desc"),
        ["page"] = CaesAiJsonSchema.Integer(1),
        ["pageSize"] = CaesAiJsonSchema.Integer(1),
        ["displayByPeriod"] = new JsonObject { ["type"] = "boolean" },
        ["includeZeroAmounts"] = new JsonObject { ["type"] = "boolean" },
    }, "filters", "includeState", "sortBy", "sortDirection", "page", "pageSize", "displayByPeriod", "includeZeroAmounts");

    private static JsonObject SetFiltersInputSchema()
    {
        var properties = FilterProperties();
        properties["includeState"] = IncludeStateSchema();
        return CaesAiJsonSchema.Object(properties);
    }
}
