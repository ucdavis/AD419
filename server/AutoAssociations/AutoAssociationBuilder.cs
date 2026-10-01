using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Server.Core.Data;
using Server.Models;

namespace Server.AutoAssociations;

public sealed class AutoAssociationBuilder(DataDbContext db, ILogger<AutoAssociationBuilder> logger) : IAutoAssociationBuilder
{
    public async Task BuildAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        // The build scans both transaction tables through the inclusion view;
        // EF's 30 second default is not enough on a real cycle.
        db.Database.SetCommandTimeout(DataDbConnection.ImportCommandTimeoutSeconds);

        var cycleStart = new SqlParameter("@cycleStart", System.Data.SqlDbType.Date)
        {
            Value = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
        };
        var cycleEnd = new SqlParameter("@cycleEnd", System.Data.SqlDbType.Date)
        {
            Value = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
        };

        logger.LogInformation("Building auto-associations for {FiscalYear}", cycle.FiscalYear);
        try
        {
            await db.Database.ExecuteSqlRawAsync(
                "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
                new object[] { cycleStart, cycleEnd },
                cancellationToken);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // 50000 is the number every THROW in the procedure uses; anything
            // else (timeout, connectivity) is unexpected and propagates as is.
            logger.LogWarning(ex, "Auto-association build rejected: {Message}", ex.Message);
            throw new AutoAssociationBuildException(ex.Message, ex);
        }

        logger.LogInformation("Auto-associations built for {FiscalYear}", cycle.FiscalYear);
    }

    public Task ClearAsync(CancellationToken cancellationToken)
    {
        db.Database.SetCommandTimeout(DataDbConnection.ImportCommandTimeoutSeconds);

        return db.Database.ExecuteSqlRawAsync(
            """
            DELETE FROM [data].[StagedAssociations];
            DELETE FROM [data].[AutoAssociationExcludedProjects];
            DELETE FROM [data].[ExpenseSummary];
            DELETE FROM [data].[AutoAssociationBuilds];
            """,
            cancellationToken);
    }
}
