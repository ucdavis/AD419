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
        sql.Should().Contain("[data].[ExpenseReviewTransactionFacts]");
        sql.Should().Contain("[data].[ExpenseReviewTransactionReasons]");
        sql.Should().Contain("ORDER BY");
        sql.Should().Contain("t.[Source]");
        sql.Should().Contain("CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod]");
        sql.Should().NotContain("t.[AccountingPeriod],");
    }

    [Fact]
    public void BuildTransactionsSql_aggregates_reasons_after_pagination()
    {
        var sql = ExpenseReviewService.BuildTransactionsSql(Request());

        sql.Should().Contain("INNER JOIN #PagedGroupIds p ON p.[Id] = t.[GroupId]");
        sql.Should().Contain("[data].[ExpenseReviewTransactionReasons]");
        sql.Should().NotContain("INTO #CycleReasons");
        sql.Should().NotContain("INTO #FilteredReasons");
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

    private static string PagedOrderByClause(string sql)
    {
        var offsetIndex = sql.IndexOf("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY", StringComparison.Ordinal);
        var orderByIndex = sql.LastIndexOf("ORDER BY", offsetIndex, StringComparison.Ordinal);
        return sql[orderByIndex..offsetIndex];
    }

    private static ExpenseReviewTransactionsRequest Request(bool displayByPeriod = false, string sortBy = ExpenseReviewRequestParser.DefaultSortBy) =>
        new(
            ExpenseReviewIncludeState.All,
            1,
            50,
            sortBy,
            false,
            displayByPeriod,
            new ExpenseReviewFilters([], [], [], [], [], [], [], [], [], [], [], []));
}
