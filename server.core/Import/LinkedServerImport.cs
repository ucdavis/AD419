using System.Data.Common;
using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;
using Server.Core.Data;

namespace Server.Core.Import;

public sealed record ImportColumnMapping(string Source, string Destination);

public interface ILinkedServerQueryExecutor
{
    Task<TResult> ExecuteReaderAsync<TResult>(
        string connectionString,
        string commandText,
        IReadOnlyList<SqlParameter> parameters,
        Func<DbDataReader, CancellationToken, Task<TResult>> readAsync,
        CancellationToken cancellationToken);
}

public sealed class LinkedServerQueryExecutor(ILogger<LinkedServerQueryExecutor> logger) : ILinkedServerQueryExecutor
{
    public async Task<TResult> ExecuteReaderAsync<TResult>(
        string connectionString,
        string commandText,
        IReadOnlyList<SqlParameter> parameters,
        Func<DbDataReader, CancellationToken, Task<TResult>> readAsync,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(connectionString);
        await ImportDiagnostics.PhaseAsync(logger, "Source connection", async () =>
        {
            await connection.OpenAsync(cancellationToken);
            return true;
        });

        await using var command = new SqlCommand(commandText, connection)
        {
            CommandTimeout = DataDbConnection.ImportCommandTimeoutSeconds,
        };

        foreach (var parameter in parameters)
        {
            command.Parameters.Add(parameter);
        }

        await using var reader = await ImportDiagnostics.PhaseAsync(logger, "Source reader",
            () => command.ExecuteReaderAsync(cancellationToken));
        return await readAsync(reader, cancellationToken);
    }
}

public interface ISqlBulkCopyWriter
{
    Task<long> WriteToServerAsync(
        SqlConnection destination,
        SqlTransaction? transaction,
        string destinationTableName,
        IReadOnlyList<ImportColumnMapping> mappings,
        DbDataReader reader,
        CancellationToken cancellationToken);
}

public sealed class SqlBulkCopyWriter(ILogger<SqlBulkCopyWriter> logger) : ISqlBulkCopyWriter
{
    public async Task<long> WriteToServerAsync(
        SqlConnection destination,
        SqlTransaction? transaction,
        string destinationTableName,
        IReadOnlyList<ImportColumnMapping> mappings,
        DbDataReader reader,
        CancellationToken cancellationToken)
    {
        using var scope = logger.BeginScope(new Dictionary<string, object?> { ["DestinationTable"] = destinationTableName });
        return await ImportDiagnostics.PhaseAsync(logger, "Bulk copy", async () =>
        {
            using var bulkCopy = transaction is null
                ? new SqlBulkCopy(destination)
                : new SqlBulkCopy(destination, SqlBulkCopyOptions.Default, transaction);

            bulkCopy.DestinationTableName = destinationTableName;
            bulkCopy.BulkCopyTimeout = DataDbConnection.ImportCommandTimeoutSeconds;

            foreach (var mapping in mappings)
            {
                bulkCopy.ColumnMappings.Add(mapping.Source, mapping.Destination);
            }

            await bulkCopy.WriteToServerAsync(reader, cancellationToken);
            return bulkCopy.RowsCopied64;
        });
    }
}
