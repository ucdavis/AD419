using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;

namespace Server.ExpenseReview;

public sealed class ConfirmedCycleProvider(AppDbContext appDb) : IConfirmedCycleProvider
{
    public async Task<FiscalYearCycle?> GetAsync(CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out _))
        {
            return null;
        }

        return new FiscalYearCycle(run.FiscalYear, run.CycleStart, run.CycleEnd);
    }
}
