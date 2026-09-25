using Server.Models;

namespace Server.AutoAssociations;

/// <summary>
/// Builds and clears the auto-association staging data (expense summary,
/// staged associations, excluded projects, build record) for the current cycle.
/// </summary>
public interface IAutoAssociationBuilder
{
    Task BuildAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    Task ClearAsync(CancellationToken cancellationToken);
}
