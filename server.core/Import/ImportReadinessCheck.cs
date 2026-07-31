using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;

namespace Server.Core.Import;

public interface IImportReadinessCheck
{
    /// <summary>
    /// Returns the reason an import run cannot start, or null when it can. Reads
    /// [data].[v_ImportBlockingIssue], the same definition the BuildProjects guard
    /// uses, so a not-ready run is rejected at the trigger instead of failing at
    /// the build projects stage mid-run.
    /// </summary>
    Task<string?> GetBlockingIssueAsync(CancellationToken cancellationToken);
}

public sealed class ImportReadinessCheck : IImportReadinessCheck
{
    private const string CheckSql = "SELECT [Issue] FROM [data].[v_ImportBlockingIssue]";

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;

    public ImportReadinessCheck(DataDbContext dataDbContext, IConfiguration configuration)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
    }

    public async Task<string?> GetBlockingIssueAsync(CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(CheckSql, connection);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is DBNull or null ? null : (string)result;
    }
}
