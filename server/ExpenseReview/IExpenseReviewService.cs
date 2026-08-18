using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public interface IExpenseReviewService
{
    Task<ExpenseReviewTransactionsResponse> GetTransactionsAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        CancellationToken cancellationToken);

    Task<ExpenseReviewFilterOptionsResponse> GetFilterOptionsAsync(
        FiscalYearCycle cycle,
        CancellationToken cancellationToken);

    Task WriteTransactionsCsvAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        IReadOnlyList<string> columnIds,
        Stream output,
        CancellationToken cancellationToken);
}
