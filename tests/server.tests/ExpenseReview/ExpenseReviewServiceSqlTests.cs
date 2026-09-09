using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewServiceSqlTests
{
    [Fact]
    public void BuildTransactionsExportSql_does_not_paginate()
    {
        var sql = ExpenseReviewService.BuildTransactionsExportSql(Request());

        sql.Should().NotContain("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY");
        sql.Should().Contain("INTO #Grouped");
        sql.Should().Contain("INTO #AggregatedReasons");
        sql.Should().Contain("ORDER BY");
        sql.Should().Contain("t.[Source]");
        sql.Should().Contain("CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod]");
        sql.Should().NotContain("t.[AccountingPeriod],");
    }

    [Fact]
    public void BuildTransactionsSql_groups_by_accounting_period_when_requested()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(displayByPeriod: true));

        sql.Should().Contain("t.[AccountingPeriod],");
        sql.Should().Contain("t.[AccountingPeriodSort]");
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

        sql.Should().Contain("HAVING SUM(t.[Amount]) <> 0 OR SUM(t.[Amount]) IS NULL");
    }

    [Fact]
    public void BuildTransactionsSql_can_include_zero_amount_groups()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request(includeZeroAmounts: true));

        sql.Should().NotContain("HAVING SUM(t.[Amount])");
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

    private static string PagedOrderByClause(string sql)
    {
        var offsetIndex = sql.IndexOf("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY", StringComparison.Ordinal);
        var orderByIndex = sql.LastIndexOf("ORDER BY", offsetIndex, StringComparison.Ordinal);
        return sql[orderByIndex..offsetIndex];
    }

    private static ExpenseReviewTransactionsRequest Request(
        bool displayByPeriod = false,
        string sortBy = ExpenseReviewRequestParser.DefaultSortBy,
        bool includeZeroAmounts = false) =>
        new(
            ExpenseReviewIncludeState.All,
            1,
            50,
            sortBy,
            false,
            displayByPeriod,
            includeZeroAmounts,
            new ExpenseReviewFilters([], [], [], [], [], [], [], [], [], [], [], []));
}
