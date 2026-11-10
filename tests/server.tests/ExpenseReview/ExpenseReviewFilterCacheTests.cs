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
    public async Task Completed_indexes_are_reused_until_explicit_invalidation()
    {
        var cache = Cache();
        var index = Index();
        var calls = 0;
        Task<ExpenseReviewFilterIndex> Build()
        {
            calls++;
            return Task.FromResult(index);
        }

        for (var request = 0; request < 100; request++)
        {
            (await cache.GetAsync(Cycle(), Build, CancellationToken.None)).Should().BeSameAs(index);
        }
        calls.Should().Be(1);

        cache.InvalidateAll();
        calls.Should().Be(1);
        var replacement = Index();
        (await cache.GetAsync(Cycle(), () => Task.FromResult(replacement), CancellationToken.None))
            .Should().BeSameAs(replacement);
    }

    [Fact]
    public async Task Repeated_edits_release_all_cycles_without_building_until_one_shared_request()
    {
        var cache = Cache();
        var secondCycle = Cycle() with { FiscalYear = "FY26" };
        var oldIndex = Index();
        await cache.GetAsync(Cycle(), () => Task.FromResult(oldIndex), CancellationToken.None);
        await cache.GetAsync(secondCycle, () => Task.FromResult(oldIndex), CancellationToken.None);
        for (var edit = 0; edit < 20; edit++)
        {
            cache.InvalidateAll();
        }

        var completion = Completion();
        var calls = 0;
        Task<ExpenseReviewFilterIndex> Build()
        {
            Interlocked.Increment(ref calls);
            return completion.Task;
        }
        var callers = Enumerable.Range(0, 20)
            .Select(_ => cache.GetAsync(Cycle(), Build, CancellationToken.None)).ToArray();
        calls.Should().Be(1);
        var next = Index();
        completion.SetResult(next);
        (await Task.WhenAll(callers)).Should().OnlyContain(index => ReferenceEquals(index, next));
        (await cache.GetAsync(secondCycle, () => Task.FromResult(next), CancellationToken.None))
            .Should().BeSameAs(next);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Invalidated_build_finishes_for_original_callers_without_replacing_new_cache_entry(bool fail)
    {
        var cache = Cache();
        var original = Completion();
        var first = cache.GetAsync(Cycle(), () => original.Task, CancellationToken.None);

        cache.InvalidateAll();
        first.IsCompleted.Should().BeFalse();

        var replacement = Completion();
        var next = cache.GetAsync(Cycle(), () => replacement.Task, CancellationToken.None);
        var shared = cache.GetAsync(Cycle(), () => throw new Exception("duplicate build"), CancellationToken.None);
        var newIndex = Index();
        replacement.SetResult(newIndex);
        (await next).Should().BeSameAs(newIndex);
        (await shared).Should().BeSameAs(newIndex);
        first.IsCompleted.Should().BeFalse("the replacement does not wait for the obsolete build");

        if (fail)
        {
            original.SetException(new InvalidOperationException("original failure"));
            await Assert.ThrowsAsync<InvalidOperationException>(() => first);
        }
        else
        {
            var oldIndex = Index();
            original.SetResult(oldIndex);
            (await first).Should().BeSameAs(oldIndex);
        }

        (await cache.GetAsync(Cycle(), () => throw new Exception("replacement removed"), CancellationToken.None))
            .Should().BeSameAs(newIndex);
    }

    [Fact]
    public async Task Already_canceled_request_never_starts_a_build()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Cache().GetAsync(
            Cycle(), () => throw new Exception("must not build"), cancellation.Token));
    }

    private static ExpenseReviewFilterCache Cache() => new();
    private static FiscalYearCycle Cycle() => new("FY25", new(2024, 10, 1), new(2025, 9, 30));
    private static TaskCompletionSource<ExpenseReviewFilterIndex> Completion() => new(TaskCreationOptions.RunContinuationsAsynchronously);
    private static ExpenseReviewFilterIndex Index() => ExpenseReviewFilterIndex.Build(new([], [], [], [], [], [], [], [], [], [], [], []), []);

}
