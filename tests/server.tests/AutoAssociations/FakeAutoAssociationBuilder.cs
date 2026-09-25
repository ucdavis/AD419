using Server.AutoAssociations;
using Server.Models;

namespace Server.Tests.AutoAssociations;

internal sealed class FakeAutoAssociationBuilder : IAutoAssociationBuilder
{
    public List<FiscalYearCycle> Builds { get; } = [];
    public int Clears { get; private set; }
    public Exception? BuildFailure { get; set; }

    public Task BuildAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        if (BuildFailure is not null)
        {
            throw BuildFailure;
        }

        Builds.Add(cycle);
        return Task.CompletedTask;
    }

    public Task ClearAsync(CancellationToken cancellationToken)
    {
        Clears++;
        return Task.CompletedTask;
    }
}
