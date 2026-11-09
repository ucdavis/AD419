using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;
using Server.Core.ExpenseReview;

namespace Server.Core.Import;

public sealed class SprocStageService
{
    private const int CommandTimeoutSeconds = DataDbConnection.ImportCommandTimeoutSeconds;

    private readonly DataDbContext _dataDbContext;
    private readonly IConfiguration _configuration;
    private readonly IExpenseReviewFilterCacheInvalidator _filterCacheInvalidator;

    public SprocStageService(
        DataDbContext dataDbContext,
        IConfiguration configuration,
        IExpenseReviewFilterCacheInvalidator filterCacheInvalidator)
    {
        _dataDbContext = dataDbContext;
        _configuration = configuration;
        _filterCacheInvalidator = filterCacheInvalidator;
    }

    public async Task<ImportStageResult> BuildProjectsAsync(
        DateOnly cycleStart,
        DateOnly cycleEnd,
        CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
        await using var command = new SqlCommand("[data].[BuildProjects]", connection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = CommandTimeoutSeconds,
        };
        command.Parameters.Add(new SqlParameter("@CycleStart", SqlDbType.Date) { Value = cycleStart.ToDateTime(TimeOnly.MinValue) });
        command.Parameters.Add(new SqlParameter("@CycleEnd", SqlDbType.Date) { Value = cycleEnd.ToDateTime(TimeOnly.MinValue) });

        var result = new ImportStageResult(0);
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            if (await reader.ReadAsync(cancellationToken))
            {
                var aeProjects = reader.GetInt32(reader.GetOrdinal("AeProjects"));
                var nifaProjects = reader.GetInt32(reader.GetOrdinal("NifaProjects"));
                result = new ImportStageResult(
                    aeProjects,
                    $"{aeProjects:N0} AE projects, {nifaProjects:N0} NIFA projects");
            }
        }

        await transaction.CommitAsync(cancellationToken);
        _filterCacheInvalidator.InvalidateAll();
        return result;
    }

    public async Task<int> SeedSegmentClassificationsAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenConnectionAsync(cancellationToken);
        await using var command = new SqlCommand("[data].[SeedSegmentClassifications]", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = CommandTimeoutSeconds,
        };

        try
        {
            var total = 0;
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            var insertedCountOrdinal = reader.GetOrdinal("InsertedCount");
            while (await reader.ReadAsync(cancellationToken))
            {
                total += reader.GetInt32(insertedCountOrdinal);
            }

            return total;
        }
        finally
        {
            // The procedure uses multiple autocommit statements. An error or
            // cancellation can follow an earlier committed write.
            _filterCacheInvalidator.InvalidateAll();
        }
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

        try
        {
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                return 0;
            }

            var aeRowsClassified = reader.GetInt32(reader.GetOrdinal("AeRowsClassified"));
            var ucPathRowsClassified = reader.GetInt32(reader.GetOrdinal("UcPathRowsClassified"));
            return aeRowsClassified + ucPathRowsClassified;
        }
        finally
        {
            // Statements can commit before a later failure; clearing an unchanged cache is harmless.
            _filterCacheInvalidator.InvalidateAll();
        }
    }

    private async Task<SqlConnection> OpenConnectionAsync(CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(_configuration, _dataDbContext.Database.GetConnectionString());
        var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}
