using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;

namespace Server.Core.Import;

public interface IImportReadinessCheck
{
    /// <summary>
    /// Returns the reason an import run cannot start for the given cycle, or
    /// null when it can. Reads [data].[ImportBlockingIssueForCycle], the same
    /// definition the BuildProjects guard uses, so a not-ready run is rejected
    /// at the trigger instead of failing at the build projects stage mid-run.
    /// </summary>
    Task<string?> GetBlockingIssueAsync(DateOnly cycleStart, DateOnly cycleEnd, CancellationToken cancellationToken);
}

public sealed class ImportReadinessCheck : IImportReadinessCheck
{
    private const string CheckSql =
        "SELECT [data].[ImportBlockingIssueForCycle](@cycleStart, @cycleEnd)";

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;

    public ImportReadinessCheck(DataDbContext dataDbContext, IConfiguration configuration)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
    }

    public async Task<string?> GetBlockingIssueAsync(
        DateOnly cycleStart,
        DateOnly cycleEnd,
        CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(CheckSql, connection);
        command.Parameters.Add(new SqlParameter("@cycleStart", SqlDbType.Date) { Value = cycleStart.ToDateTime(TimeOnly.MinValue) });
        command.Parameters.Add(new SqlParameter("@cycleEnd", SqlDbType.Date) { Value = cycleEnd.ToDateTime(TimeOnly.MinValue) });
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is DBNull or null ? null : (string)result;
    }
}
