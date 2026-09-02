using Server.ExpenseReview;
using Server.Models;

namespace Server.Tests.ExpenseReview;

public sealed class StubExpenseReviewCacheService : IExpenseReviewCacheService
{
    public int EnsureCount { get; private set; }

    public int ForceRefreshCount { get; private set; }

    public int InvalidateCount { get; private set; }

    public FiscalYearCycle? LastForcedCycle { get; private set; }

    public Task EnsureCachePreparedAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        EnsureCount++;
        return Task.CompletedTask;
    }

    public Task ForceRefreshAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        ForceRefreshCount++;
        LastForcedCycle = cycle;
        return Task.CompletedTask;
    }

    public Task InvalidateAsync(CancellationToken cancellationToken)
    {
        InvalidateCount++;
        return Task.CompletedTask;
    }
}
