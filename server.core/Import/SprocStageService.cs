using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed class SprocStageService
{
    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;

    public SprocStageService(DataDbContext dataDbContext, IConfiguration configuration)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
    }

    public async Task<ImportStageResult> BuildProjectsAsync(
        DateOnly cycleStart,
        DateOnly cycleEnd,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = new SqlCommand("[data].[BuildProjects]", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = CommandTimeoutSeconds,
        };
        command.Parameters.Add(new SqlParameter("@CycleStart", SqlDbType.Date) { Value = cycleStart.ToDateTime(TimeOnly.MinValue) });
        command.Parameters.Add(new SqlParameter("@CycleEnd", SqlDbType.Date) { Value = cycleEnd.ToDateTime(TimeOnly.MinValue) });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return new ImportStageResult(0);
        }

        var aeProjects = reader.GetInt32(reader.GetOrdinal("AeProjects"));
        var nifaProjects = reader.GetInt32(reader.GetOrdinal("NifaProjects"));
        return new ImportStageResult(
            aeProjects,
            $"{aeProjects:N0} AE projects, {nifaProjects:N0} NIFA projects");
    }

    public async Task<int> SeedSegmentClassificationsAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = new SqlCommand("[data].[SeedSegmentClassifications]", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = CommandTimeoutSeconds,
        };

        var total = 0;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var insertedCountOrdinal = reader.GetOrdinal("InsertedCount");
        while (await reader.ReadAsync(cancellationToken))
        {
            total += reader.GetInt32(insertedCountOrdinal);
        }

        return total;
    }

    public async Task<int> ClassifyTransactionsAsync(DateOnly cycleStart, DateOnly cycleEnd, CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = new SqlCommand("[data].[ClassifyTransactions]", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = CommandTimeoutSeconds,
        };
        command.Parameters.Add(new SqlParameter("@cycleStart", SqlDbType.Date) { Value = cycleStart.ToDateTime(TimeOnly.MinValue) });
        command.Parameters.Add(new SqlParameter("@cycleEnd", SqlDbType.Date) { Value = cycleEnd.ToDateTime(TimeOnly.MinValue) });

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return 0;
        }

        var aeRowsClassified = reader.GetInt32(reader.GetOrdinal("AeRowsClassified"));
        var ucPathRowsClassified = reader.GetInt32(reader.GetOrdinal("UcPathRowsClassified"));
        return aeRowsClassified + ucPathRowsClassified;
    }

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(_configuration, _dataDbContext.Database.GetConnectionString());
        var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}
