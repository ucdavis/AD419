using Server.Core.ExpenseReview;

namespace Server.Tests.Helpers;

internal sealed class RecordingExpenseReviewFilterCacheInvalidator(Action? onInvalidate = null)
    : IExpenseReviewFilterCacheInvalidator
{
    public int Calls { get; private set; }

    public void InvalidateAll()
    {
        Calls++;
        onInvalidate?.Invoke();
    }
}
