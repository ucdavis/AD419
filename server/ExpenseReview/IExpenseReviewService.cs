using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public interface IExpenseReviewService
{
    Task<ExpenseReviewGroupTransactionsResponse?> GetGroupTransactionsAsync(
        FiscalYearCycle cycle,
        ExpenseReviewGroupTransactionsRequest request,
        CancellationToken cancellationToken);

    Task WriteGroupTransactionsCsvAsync(
        FiscalYearCycle cycle,
        ExpenseReviewGroupTransactionsRequest request,
        ExpenseReviewTransactionDto group,
        Stream output,
        CancellationToken cancellationToken);

    Task<ExpenseReviewTransactionsResponse> GetTransactionsAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        CancellationToken cancellationToken);

    Task<ExpenseReviewFilterOptionsResponse> GetFilterOptionsAsync(
        FiscalYearCycle cycle,
        CancellationToken cancellationToken);

    Task<UnmatchedJobCodesResponse> GetUnmatchedJobCodesAsync(
        FiscalYearCycle cycle,
        CancellationToken cancellationToken);

    Task<ExpenseReviewSummaryResponse> GetSummaryAsync(
        FiscalYearCycle cycle,
        ExpenseReviewSummaryRequest request,
        CancellationToken cancellationToken);

    Task WriteTransactionsCsvAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        Stream output,
        CancellationToken cancellationToken);
}
