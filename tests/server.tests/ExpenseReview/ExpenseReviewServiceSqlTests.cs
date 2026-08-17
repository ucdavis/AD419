using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewServiceSqlTests
{
    [Fact]
    public void Unified_sql_includes_both_transaction_sources()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("FROM [data].[AETransactions] a");
        sql.Should().Contain("FROM [data].[UcPathTransactions] u");
        sql.Should().Contain("UNION ALL");
        sql.Should().Contain("CAST('AE' AS NVARCHAR(3)) AS [Source]");
        sql.Should().Contain("CAST('UCP' AS NVARCHAR(3)) AS [Source]");
    }

    [Fact]
    public void Unified_sql_returns_stable_row_identity_fields()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("CAST(CONCAT('AE:', a.[Id]) AS NVARCHAR(160)) AS [Id]");
        sql.Should().Contain("CAST(a.[Id] AS NVARCHAR(125)) AS [SourceId]");
        sql.Should().Contain("CAST(CONCAT('UCP:', u.[LaborTransactionId]) AS NVARCHAR(160)) AS [Id]");
        sql.Should().Contain("u.[LaborTransactionId] AS [SourceId]");
    }

    [Fact]
    public void Unified_sql_uses_expected_description_sources_for_hover_names()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("a.[FinancialDepartmentDescription] AS [FinancialDeptName]");
        sql.Should().Contain("a.[FundDescription] AS [FundName]");
        sql.Should().Contain("a.[AccountDescription] AS [AccountName]");
        sql.Should().Contain("a.[ProjectDescription] AS [AeProjectName]");
        sql.Should().Contain("LEFT JOIN [data].[ChartSegments] financialDeptSegment");
        sql.Should().Contain("LEFT JOIN [data].[ChartSegments] fundSegment");
        sql.Should().Contain("LEFT JOIN [data].[ChartSegments] accountSegment");
        sql.Should().Contain("LEFT JOIN [data].[ChartSegments] projectSegment");
        sql.Should().Contain("COALESCE(NULLIF(projectSegment.[ValueDesc], ''), NULLIF(projectSegment.[Description], '')) AS [AeProjectName]");
    }

    [Fact]
    public void Unified_sql_resolves_accounting_period_source_sfn_amount_and_fte()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("a.[PeriodName] AS [AccountingPeriod]");
        sql.Should().Contain("FORMAT(ucPeriod.[PeriodStart], 'MMM-yy', 'en-US')");
        sql.Should().Contain("fundClass.[Sfn] AS [Sfn]");
        sql.Should().Contain("LEFT JOIN [data].[Sfns] sfn");
        sql.Should().Contain("sfn.[Label] AS [SfnLabel]");
        sql.Should().Contain("a.[Amount] AS [Amount]");
        sql.Should().Contain("u.[Amount] AS [Amount]");
        sql.Should().Contain("CAST(NULL AS DECIMAL(9, 6)) AS [Fte]");
        sql.Should().Contain("u.[CalculatedFte] AS [Fte]");
        sql.Should().Contain("CAST(0 AS BIT) AS [FteIncluded]");
        sql.Should().Contain("END AS [FteIncluded]");
    }

    [Fact]
    public void Dollar_include_predicates_fail_closed_for_persisted_flags_and_classifications()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("a.[ExcludedByDate] = 0");
        sql.Should().Contain("a.[AccountInUcPath] = 0");
        sql.Should().Contain("u.[ExcludedByDate] = 0");
        sql.Should().Contain("u.[AccountNotInAE] = 0");
        sql.Should().Contain("COALESCE(financialDeptClass.[IncludeInReport], 0) = 1");
        sql.Should().Contain("COALESCE(fundClass.[IncludeInReport], 0) = 1");
        sql.Should().Contain("COALESCE(accountClass.[IncludeInReport], 0) = 1");
        sql.Should().Contain("COALESCE(activityClass.[IncludeInReport], 0) = 1");
        sql.Should().Contain("(a.[Fund] = '13U02' OR COALESCE(purposeClass.[IncludeInReport], 0) = 1)");
        sql.Should().Contain("(u.[Fund] = '13U02' OR COALESCE(purposeClass.[IncludeInReport], 0) = 1)");
        sql.Should().Contain("TODO: Seek stakeholder review on this fail-closed null/missing classification behavior.");
        sql.Should().NotContain("ISNULL(a.[ExcludedByDate], 0)");
        sql.Should().NotContain("ISNULL(u.[ExcludedByDate], 0)");
    }

    [Fact]
    public void Fte_inclusion_uses_ern_classification_without_excluding_ucpath_dollars()
    {
        var sql = ExpenseReviewService.UnifiedTransactionsCte;

        sql.Should().Contain("AND COALESCE(ernClass.[IncludeInReport], 0) = 1");
        sql.Should().Contain("END AS [FteIncluded]");

        var dollarIncludedStart = sql.IndexOf("END AS [FteIncluded]", StringComparison.Ordinal);
        dollarIncludedStart.Should().BeGreaterThanOrEqualTo(0);
        sql[dollarIncludedStart..].Should().NotContain("COALESCE(ernClass.[IncludeInReport], 0) = 1");
    }

    [Fact]
    public void Transaction_sql_returns_counts_and_applies_include_state()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(includeState: ExpenseReviewIncludeState.Included));

        sql.Should().Contain("SELECT *\nINTO #Filtered\nFROM Filtered;");
        sql.Should().Contain("COUNT(1) AS [All]");
        sql.Should().Contain("COALESCE(SUM(CASE WHEN [Included] = 1 THEN 1 ELSE 0 END), 0) AS [Included]");
        sql.Should().Contain("COALESCE(SUM(CASE WHEN [Included] = 0 THEN 1 ELSE 0 END), 0) AS [Excluded]");
        sql.Should().Contain("FROM #Filtered;");
        sql.Should().Contain("FROM #Filtered\nWHERE [Included] = 1");
        sql.Should().Contain("WHERE [Included] = 1");
        sql.Should().NotContain("FROM IncludedFiltered");
        sql.Should().Contain("[FteIncluded]");
    }

    [Fact]
    public void Transaction_sql_applies_filters_sorting_and_pagination()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(
            sortBy: "amount",
            sortDescending: true,
            filters: new ExpenseReviewFilters(
                ["D0123"],
                ["45530"],
                ["500000"],
                ["K1234"],
                ["Oct-24"],
                ["AE"],
                ["220"])));

        sql.Should().Contain("[FinancialDeptCode] IN @financialDept");
        sql.Should().Contain("[FundCode] IN @fund");
        sql.Should().Contain("[AccountCode] IN @account");
        sql.Should().Contain("[AeProjectCode] IN @aeProject");
        sql.Should().Contain("[AccountingPeriod] IN @accountingPeriod");
        sql.Should().Contain("[Source] IN @source");
        sql.Should().Contain("[Sfn] IN @sfn");
        sql.Should().Contain("[Amount] DESC");
        sql.Should().Contain("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY");
    }

    [Fact]
    public void Filter_options_sql_exposes_server_filter_sources()
    {
        var sql = ExpenseReviewService.FilterOptionsSql;

        sql.Should().Contain("CAST('financialDept' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('fund' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('account' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('aeProject' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('accountingPeriod' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('source' AS NVARCHAR(30)) AS [Filter]");
        sql.Should().Contain("CAST('sfn' AS NVARCHAR(30)) AS [Filter]");
    }

    private static ExpenseReviewTransactionsRequest Request(
        ExpenseReviewIncludeState includeState = ExpenseReviewIncludeState.All,
        string sortBy = ExpenseReviewRequestParser.DefaultSortBy,
        bool sortDescending = false,
        ExpenseReviewFilters? filters = null) =>
        new(
            includeState,
            1,
            50,
            sortBy,
            sortDescending,
            filters ?? new ExpenseReviewFilters([], [], [], [], [], [], []));
}
