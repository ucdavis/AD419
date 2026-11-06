namespace Server.ExpenseReview;

internal static class ExpenseReviewPeriodSql
{
    internal static string UcPathPeriodStart(string fiscalYearExpression, string periodNumberExpression) => $$"""
        CASE
            WHEN {{periodNumberExpression}} BETWEEN 1 AND 12
            THEN DATEFROMPARTS(
                CASE WHEN {{periodNumberExpression}} BETWEEN 1 AND 6 THEN {{fiscalYearExpression}} - 1
                     ELSE {{fiscalYearExpression}} END,
                (({{periodNumberExpression}} + 5) % 12) + 1,
                1)
            ELSE NULL
        END
        """;
}
