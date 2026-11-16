namespace Server.ExpenseReview;

// The report can be invalidated after CSV preflight but before streaming starts.
public sealed class ExpenseReviewEmployeeTransactionsUnavailableException(bool buildAvailable)
    : Exception(buildAvailable ? "The employee is no longer in the report." : "The auto-association build is no longer available.")
{
    public bool BuildAvailable { get; } = buildAvailable;
}
