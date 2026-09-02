using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;

namespace Server.ExpenseReview;

public sealed class ExpenseReviewCacheService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IExpenseReviewCacheService
{
    public Task EnsureCachePreparedAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
        RefreshAsync(cycle, force: false, cancellationToken);

    public Task ForceRefreshAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
        RefreshAsync(cycle, force: true, cancellationToken);

    public async Task InvalidateAsync(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await connection.ExecuteAsync(new CommandDefinition(
            "DELETE FROM [data].[ExpenseReviewCacheStatus];",
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));
    }

    private async Task RefreshAsync(
        FiscalYearCycle cycle,
        bool force,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await connection.ExecuteAsync(new CommandDefinition(
            "[data].[RefreshExpenseReviewCache]",
            new
            {
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
                force,
            },
            commandType: CommandType.StoredProcedure,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));
    }

    private SqlConnection CreateConnection()
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        return new SqlConnection(connectionString);
    }
}
