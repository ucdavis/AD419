using Server.Core.ExpenseReview;
using Server.Models;

namespace Server.ExpenseReview;

// Coordinates just the cycle-wide dropdown indexes. No request token or scoped service is retained.
public sealed class ExpenseReviewFilterCache(ILogger<ExpenseReviewFilterCache>? logger = null)
    : IExpenseReviewFilterCacheInvalidator
{
    private readonly object _gate = new();
    private readonly Dictionary<FiscalYearCycle, TaskCompletionSource<ExpenseReviewFilterIndex>> _entries = [];

    public void InvalidateAll()
    {
        lock (_gate)
        {
            // Existing callers keep their task; the next request starts a fresh build.
            _entries.Clear();
        }

        logger?.LogInformation("Invalidated expense review filter indexes");
    }

    public Task<ExpenseReviewFilterIndex> GetAsync(
        FiscalYearCycle cycle,
        Func<Task<ExpenseReviewFilterIndex>> build,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        TaskCompletionSource<ExpenseReviewFilterIndex> completion;
        var start = false;
        lock (_gate)
        {
            if (!_entries.TryGetValue(cycle, out completion!))
            {
                completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
                _entries.Add(cycle, completion);
                start = true;
            }
        }

        if (start)
        {
            _ = CompleteAsync(cycle, completion, build);
        }

        return completion.Task.WaitAsync(cancellationToken);
    }

    private async Task CompleteAsync(
        FiscalYearCycle cycle,
        TaskCompletionSource<ExpenseReviewFilterIndex> completion,
        Func<Task<ExpenseReviewFilterIndex>> build)
    {
        try
        {
            logger?.LogInformation("Building expense review filter index for {FiscalYear}", cycle.FiscalYear);
            completion.SetResult(await build());
        }
        catch (Exception exception)
        {
            lock (_gate)
            {
                // An obsolete failure must not remove a newer build after invalidation.
                if (_entries.TryGetValue(cycle, out var current) && ReferenceEquals(current, completion))
                {
                    _entries.Remove(cycle);
                }
            }

            completion.SetException(exception);
            // Observe failures even if every waiting request has already canceled.
            _ = completion.Task.Exception;
        }
    }
}
