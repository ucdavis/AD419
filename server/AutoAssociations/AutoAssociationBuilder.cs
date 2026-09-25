using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;

namespace Server.AutoAssociations;

public sealed class AutoAssociationBuilder(DataDbContext db) : IAutoAssociationBuilder
{
    public Task BuildAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        var cycleStart = new SqlParameter("@cycleStart", System.Data.SqlDbType.Date)
        {
            Value = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
        };
        var cycleEnd = new SqlParameter("@cycleEnd", System.Data.SqlDbType.Date)
        {
            Value = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
        };

        return db.Database.ExecuteSqlRawAsync(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new object[] { cycleStart, cycleEnd },
            cancellationToken);
    }

    public Task ClearAsync(CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlRawAsync(
            """
            DELETE FROM [data].[StagedAssociations];
            DELETE FROM [data].[AutoAssociationExcludedProjects];
            DELETE FROM [data].[ExpenseSummary];
            DELETE FROM [data].[AutoAssociationBuilds];
            """,
            cancellationToken);
}
