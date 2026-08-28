using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewServiceSqlTests
{
    [Fact]
    public void BuildTransactionsExportSql_does_not_paginate_or_materialize_temp_table()
    {
        var sql = ExpenseReviewService.BuildTransactionsExportSql(Request());

        sql.Should().NotContain("OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY");
        sql.Should().NotContain("INTO #Filtered");
        sql.Should().Contain("ORDER BY");
    }

    private static ExpenseReviewTransactionsRequest Request() =>
        new(
            ExpenseReviewIncludeState.All,
            1,
            50,
            ExpenseReviewRequestParser.DefaultSortBy,
            false,
            new ExpenseReviewFilters([], [], [], [], [], [], []));
}
