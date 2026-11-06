using Server.Models;

namespace Server.ExpenseReview;

// Coordinates just the cycle-wide dropdown indexes. No request token or scoped service is retained.
public sealed class ExpenseReviewFilterCache(TimeProvider? timeProvider = null)
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);
    private readonly TimeProvider _clock = timeProvider ?? TimeProvider.System;
    private readonly object _gate = new();
    private readonly Dictionary<FiscalYearCycle, Entry> _entries = [];

    public Task<ExpenseReviewFilterIndex> GetAsync(
        FiscalYearCycle cycle,
        Func<Task<ExpenseReviewFilterIndex>> build,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Entry entry;
        var start = false;
        lock (_gate)
        {
            // Drop expired cycles on access so the singleton does not retain historical indexes.
            foreach (var expired in _entries.Where(pair => pair.Value.ExpiresAt <= _clock.GetUtcNow())
                         .Select(pair => pair.Key).ToArray())
            {
                _entries.Remove(expired);
            }

            if (!_entries.TryGetValue(cycle, out entry!))
            {
                entry = new Entry();
                _entries.Add(cycle, entry);
                start = true;
            }
        }

        if (start)
        {
            _ = CompleteAsync(cycle, entry, build);
        }

        return entry.Completion.Task.WaitAsync(cancellationToken);
    }

    private async Task CompleteAsync(FiscalYearCycle cycle, Entry entry, Func<Task<ExpenseReviewFilterIndex>> build)
    {
        try
        {
            var index = await build();
            lock (_gate)
            {
                entry.ExpiresAt = _clock.GetUtcNow() + Lifetime;
                entry.Completion.SetResult(index);
            }
        }
        catch (Exception exception)
        {
            lock (_gate)
            {
                // In-flight entries cannot expire or be replaced.
                _entries.Remove(cycle);

                entry.Completion.TrySetException(exception);
                // Observe failures even if every waiting request has already canceled.
                _ = entry.Completion.Task.Exception;
            }
        }
    }

    private sealed class Entry
    {
        public TaskCompletionSource<ExpenseReviewFilterIndex> Completion { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);
        public DateTimeOffset ExpiresAt { get; set; } = DateTimeOffset.MaxValue;
    }
}
