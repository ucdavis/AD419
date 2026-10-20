using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewServiceSqlTests
{
    [Fact]
    public void BuildTransactionsExportSql_returns_reasons_before_ordered_unpaginated_transactions()
    {
        var sql = ExpenseReviewService.BuildTransactionsExportSql(Request());
        var reasonOrderIndex = sql.IndexOf(
            "ORDER BY r.[GroupId], r.[Label], r.[Code]",
            StringComparison.Ordinal);
        var transactionFromIndex = sql.LastIndexOf("FROM #Grouped g", StringComparison.Ordinal);

        sql.Should().NotContain("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY");
        sql.Should().Contain("INTO #Grouped");
        sql.Should().NotContain("INTO #AggregatedReasons");
        sql.Should().Contain("FROM #Grouped g");
        sql.Should().Contain("WHERE reason.[RowCount] > 0");
        sql.Should().Contain("ORDER BY");
        sql.Should().Contain("u.[Source]");
        sql.Should().Contain("CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod]");
        sql.Should().NotContain("u.[AccountingPeriod],");
        reasonOrderIndex.Should().BeGreaterThan(-1);
        transactionFromIndex.Should().BeGreaterThan(reasonOrderIndex);
        sql[transactionFromIndex..].Should().Contain("ORDER BY");
    }

    [Fact]
    public void BuildTransactionsSql_aggregates_directly_and_builds_reasons_after_pagination()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request());

        sql.Should().Contain("FROM Unified u");
        sql.Should().Contain("INTO #Grouped");
        sql.Should().Contain("COUNT(1) AS [GroupReasonRowCount]");
        sql.Should().Contain("[ExcludedByDateRowCount]");
        sql.Should().Contain("INNER JOIN #PagedGroupIds p ON p.[Id] = g.[Id]");
        sql.Should().NotContain("#CycleTransactions");
        sql.Should().NotContain("INTO #FilteredTransactions");
        sql.Should().NotContain("INTO #AggregatedReasons");
        CountOccurrences(sql, "HASHBYTES").Should().Be(1);
    }

    [Fact]
    public void BuildTransactionsSql_applies_reason_filter_before_direct_aggregation()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(
            filters: new ExpenseReviewFilters(
                [], [], [], [], [], [], [], [], [], [], [], ["fund:excluded"])));

        sql.Should().Contain("selectedReason([Code], [Label])");
        sql.Should().Contain("selectedReason.[Code] IN @exclusionReason");
        sql.Should().Contain("FROM Unified u");
        sql.Should().Contain("INTO #Grouped");
        sql.Should().NotContain("#CycleTransactions");
        sql.Should().NotContain("#FilteredTransactions");
        CountOccurrences(sql, "HASHBYTES").Should().Be(1);
    }

    [Fact]
    public void BuildTransactionsSql_groups_by_accounting_period_when_requested()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(displayByPeriod: true));

        sql.Should().Contain("u.[AccountingPeriod],");
        sql.Should().Contain("u.[AccountingPeriodSort]");
    }

    [Fact]
    public void BuildTransactionsSql_uses_group_id_as_final_pagination_tie_breaker()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(sortBy: "amount"));
        var orderByClause = PagedOrderByClause(sql);

        orderByClause.Should().Contain("g.[Amount] ASC");
        orderByClause.TrimEnd().Should().EndWith("g.[Id]");
    }

    [Fact]
    public void BuildTransactionsSql_keeps_group_id_final_when_sorting_by_accounting_period()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(
            displayByPeriod: true,
            sortBy: "accountingPeriod"));
        var orderByClause = PagedOrderByClause(sql);

        orderByClause.Should().Contain("g.[AccountingPeriodSort] ASC");
        orderByClause.TrimEnd().Should().EndWith("g.[Id]");
    }

    [Fact]
    public void BuildTransactionsSql_excludes_zero_amount_groups_by_default()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request());

        sql.Should().Contain("HAVING SUM(u.[Amount]) <> 0 OR SUM(u.[Amount]) IS NULL");
    }

    [Fact]
    public void BuildTransactionsSql_can_include_zero_amount_groups()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(includeZeroAmounts: true));

        sql.Should().NotContain("HAVING SUM(u.[Amount])");
    }

    [Fact]
    public void BuildTransactionsSql_uses_high_level_reason_codes_and_ucpath_fiscal_year_mapping()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request());

        sql.Should().Contain("N'fund:excluded'");
        sql.Should().Contain("N'Unclassified financial department'");
        sql.Should().NotContain("fund:F2:excluded");
        sql.Should().Contain("WHEN periodValue.[PeriodNumber] BETWEEN 1 AND 6 THEN u.[FiscalYear] - 1");
    }

    [Fact]
    public void Unified_cte_joins_the_transaction_sfn_view_for_both_sources()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("LEFT JOIN [data].[v_TransactionInclusion] incl");
        sql.Should().Contain("incl.[Source] = N'AE' AND incl.[AeTransactionId] = a.[Id]");
        sql.Should().Contain("incl.[Source] = N'UCPath' AND incl.[LaborTransactionId] = u.[LaborTransactionId]");
        sql.Should().Contain("incl.[Included] AS [Included]");
        sql.Should().Contain("incl.[Account531010OnHatchFund] AS [Account531010OnHatchFund]");
        sql.Should().NotContain("[data].[SegmentClassifications]");
        sql.Should().NotContain("[data].[v_TransactionSfn]");
    }

    [Fact]
    public void BuildTransactionsSql_returns_the_filtered_total_amount_with_the_total_count()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request());

        sql.Should().Contain("COUNT(1) AS [TotalCount]");
        sql.Should().Contain("COALESCE(SUM(g.[Amount]), 0) AS [TotalAmount]");
    }

    [Fact]
    public void BuildSummarySql_groups_by_a_dimension_code_over_the_grouped_temp_table()
    {
        var sql = ExpenseReviewService.BuildSummarySql(SummaryRequest("fund"));

        sql.Should().Contain("INTO #Grouped");
        sql.Should().Contain("GROUP BY g.[FundCode]");
        sql.Should().Contain("MAX(NULLIF(g.[FundName], N'')) AS [Name]");
        sql.Should().Contain("SELECT TOP (@limit)");
        sql.Should().Contain("ORDER BY [Amount] DESC, [Code]");
        sql.Should().NotContain("reason.[Code]");
    }

    [Fact]
    public void BuildSummarySql_orders_by_row_count_when_requested()
    {
        var sql = ExpenseReviewService.BuildSummarySql(SummaryRequest("fund", sortByRowCount: true));

        sql.Should().Contain("ORDER BY [RowCount] DESC, [Code]");
    }

    [Fact]
    public void BuildSummarySql_groups_by_accounting_period_using_period_columns()
    {
        var sql = ExpenseReviewService.BuildSummarySql(SummaryRequest("accountingPeriod"));

        sql.Should().Contain("u.[AccountingPeriod],");
        sql.Should().Contain("GROUP BY g.[AccountingPeriod]");
    }

    [Fact]
    public void BuildSummarySql_groups_exclusion_reasons_from_the_reason_values()
    {
        var sql = ExpenseReviewService.BuildSummarySql(SummaryRequest("exclusionReason"));

        sql.Should().Contain("CROSS APPLY");
        sql.Should().Contain("GROUP BY r.[Code]");
        sql.Should().Contain("SUM(r.[RowCount]) AS [RowCount]");
    }

    [Fact]
    public void BuildSummarySql_applies_the_include_state()
    {
        var sql = ExpenseReviewService.BuildSummarySql(
            SummaryRequest("fund", includeState: ExpenseReviewIncludeState.Excluded));

        sql.Should().Contain("WHERE g.[Included] = 0");
    }

    [Fact]
    public void BuildSummarySql_rejects_unknown_dimensions()
    {
        var act = () => ExpenseReviewService.BuildSummarySql(SummaryRequest("DROP TABLE"));

        act.Should().Throw<ArgumentException>();
    }

    private static ExpenseReviewSummaryRequest SummaryRequest(
        string groupBy,
        ExpenseReviewIncludeState includeState = ExpenseReviewIncludeState.All,
        bool includeZeroAmounts = false,
        bool sortByRowCount = false,
        ExpenseReviewFilters? filters = null) =>
        new(
            includeState,
            includeZeroAmounts,
            filters ?? Request().Filters,
            groupBy,
            100,
            sortByRowCount);

    private static string PagedOrderByClause(string sql)
    {
        var offsetIndex = sql.IndexOf("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY", StringComparison.Ordinal);
        var orderByIndex = sql.LastIndexOf("ORDER BY", offsetIndex, StringComparison.Ordinal);
        return sql[orderByIndex..offsetIndex];
    }

    private static int CountOccurrences(string value, string search) =>
        value.Split(search, StringSplitOptions.None).Length - 1;

    private static ExpenseReviewTransactionsRequest Request(
        bool displayByPeriod = false,
        string sortBy = ExpenseReviewRequestParser.DefaultSortBy,
        bool includeZeroAmounts = false,
        ExpenseReviewFilters? filters = null) =>
        new(
            ExpenseReviewIncludeState.All,
            1,
            50,
            sortBy,
            false,
            displayByPeriod,
            includeZeroAmounts,
            filters ?? new ExpenseReviewFilters([], [], [], [], [], [], [], [], [], [], [], []));
}
