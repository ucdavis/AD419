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
}
