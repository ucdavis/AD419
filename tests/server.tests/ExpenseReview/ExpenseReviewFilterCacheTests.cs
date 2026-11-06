using FluentAssertions;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public sealed class ExpenseReviewFilterCacheTests
{
    [Fact]
    public async Task Concurrent_callers_share_one_build_and_cancellation_only_stops_one_waiter()
    {
        var cache = Cache();
        var completion = Completion();
        var calls = 0;
        Task<ExpenseReviewFilterIndex> Build()
        {
            Interlocked.Increment(ref calls);
            return completion.Task;
        }
        using var cancellation = new CancellationTokenSource();
        var first = cache.GetAsync(Cycle(), Build, cancellation.Token);
        var callers = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Task.Run(() =>
            Task.FromResult(cache.GetAsync(Cycle(), Build, CancellationToken.None)))));
        calls.Should().Be(1);
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => first);
        callers.Should().OnlyContain(task => !task.IsCompleted);
        var index = Index();
        completion.SetResult(index);
        (await Task.WhenAll(callers)).Should().OnlyContain(result => ReferenceEquals(result, index));
        (await cache.GetAsync(Cycle(), Build, CancellationToken.None)).Should().BeSameAs(index);
        calls.Should().Be(1);
    }

    [Fact]
    public async Task Separate_cycles_build_independently()
    {
        var cache = Cache();
        var firstCompletion = Completion();
        var secondCompletion = Completion();
        var first = cache.GetAsync(Cycle(), () => firstCompletion.Task, CancellationToken.None);
        var second = cache.GetAsync(Cycle() with { FiscalYear = "FY26" }, () => secondCompletion.Task, CancellationToken.None);
        var index = Index();
        secondCompletion.SetResult(index);
        (await second).Should().BeSameAs(index);
        first.IsCompleted.Should().BeFalse();
        firstCompletion.SetResult(index);
        await first;
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Failed_builds_are_removed_before_retry_and_retry_is_shared(bool synchronousFailure)
    {
        var cache = Cache();
        var failure = Completion();
        var failed = cache.GetAsync(Cycle(), () => synchronousFailure
            ? throw new InvalidOperationException("failed") : failure.Task, CancellationToken.None);
        var secondWaiter = synchronousFailure ? failed : cache.GetAsync(Cycle(), () => throw new Exception("duplicate"), CancellationToken.None);
        if (!synchronousFailure)
        {
            failure.SetException(new InvalidOperationException("failed"));
        }
        await Assert.ThrowsAsync<InvalidOperationException>(() => failed);
        var replacement = Completion();
        var retry = cache.GetAsync(Cycle(), () => replacement.Task, CancellationToken.None);
        await Assert.ThrowsAsync<InvalidOperationException>(() => secondWaiter);
        var sharedRetry = cache.GetAsync(Cycle(), () => throw new Exception("replacement removed"), CancellationToken.None);
        replacement.SetResult(Index());
        (await sharedRetry).Should().BeSameAs(await retry);
    }

    [Fact]
    public async Task Expiration_is_ten_minutes_from_completion_and_never_expires_inflight_work()
    {
        var clock = new ManualClock();
        var cache = new ExpenseReviewFilterCache(clock);
        var completion = Completion();
        var first = cache.GetAsync(Cycle(), () => completion.Task, CancellationToken.None);
        clock.Advance(TimeSpan.FromHours(1));
        var waiting = cache.GetAsync(Cycle(), () => throw new Exception("inflight expired"), CancellationToken.None);
        var index = Index();
        completion.SetResult(index);
        await Task.WhenAll(first, waiting);
        clock.Advance(TimeSpan.FromMinutes(10) - TimeSpan.FromTicks(1));
        (await cache.GetAsync(Cycle(), () => throw new Exception("early expiry"), CancellationToken.None)).Should().BeSameAs(index);
        clock.Advance(TimeSpan.FromTicks(1));
        var next = Index();
        (await cache.GetAsync(Cycle(), () => Task.FromResult(next), CancellationToken.None)).Should().BeSameAs(next);
    }

    private static ExpenseReviewFilterCache Cache() => new();
    private static FiscalYearCycle Cycle() => new("FY25", new(2024, 10, 1), new(2025, 9, 30));
    private static TaskCompletionSource<ExpenseReviewFilterIndex> Completion() => new(TaskCreationOptions.RunContinuationsAsynchronously);
    private static ExpenseReviewFilterIndex Index() => ExpenseReviewFilterIndex.Build(new([], [], [], [], [], [], [], [], [], [], [], []), []);

    private sealed class ManualClock : TimeProvider
    {
        private DateTimeOffset _now = new(2026, 11, 5, 0, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => _now;
        public void Advance(TimeSpan duration) => _now += duration;
    }
}
