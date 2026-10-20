using Server.Models;

namespace Server.ExpenseReview;

public interface IConfirmedCycleProvider
{
    /// <summary>Returns the confirmed cycle from the current workflow run, or null when none is confirmed.</summary>
    Task<FiscalYearCycle?> GetAsync(CancellationToken cancellationToken);
}
