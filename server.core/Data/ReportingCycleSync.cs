using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Server.Core.Data;

public interface IReportingCycleSync
{
    /// <summary>
    /// Mirrors the confirmed fiscal period into the single-row
    /// [data].[ReportingCycle] snapshot so DataDb views (v_NifaProjects) window
    /// on the confirmed cycle instead of deriving one from GETDATE().
    /// </summary>
    Task SyncAsync(string fiscalYear, DateOnly cycleStart, DateOnly cycleEnd, CancellationToken cancellationToken);
}

public sealed class ReportingCycleSync : IReportingCycleSync
{
    private const string UpsertSql = """
        UPDATE [data].[ReportingCycle]
        SET [FiscalYear] = @fiscalYear,
            [CycleStart] = @cycleStart,
            [CycleEnd] = @cycleEnd,
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [Id] = 1
          AND ([FiscalYear] <> @fiscalYear
            OR [CycleStart] <> @cycleStart
            OR [CycleEnd] <> @cycleEnd);
        IF NOT EXISTS (SELECT 1 FROM [data].[ReportingCycle])
            INSERT INTO [data].[ReportingCycle] ([Id], [FiscalYear], [CycleStart], [CycleEnd])
            VALUES (1, @fiscalYear, @cycleStart, @cycleEnd);
        """;

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;

    public ReportingCycleSync(DataDbContext dataDbContext, IConfiguration configuration)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
    }

    public async Task SyncAsync(
        string fiscalYear,
        DateOnly cycleStart,
        DateOnly cycleEnd,
        CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(
            _configuration,
            _dataDbContext.Database.GetConnectionString());
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(UpsertSql, connection);
        command.Parameters.Add(new SqlParameter("@fiscalYear", SqlDbType.NVarChar, 16) { Value = fiscalYear });
        command.Parameters.Add(new SqlParameter("@cycleStart", SqlDbType.Date) { Value = cycleStart });
        command.Parameters.Add(new SqlParameter("@cycleEnd", SqlDbType.Date) { Value = cycleEnd });
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
