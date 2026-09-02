using Server.Models;

namespace Server.ExpenseReview;

public interface IExpenseReviewCacheService
{
    Task EnsureCachePreparedAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    Task ForceRefreshAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    Task InvalidateAsync(CancellationToken cancellationToken);
}
