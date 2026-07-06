using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Server.Core.Data;

public interface IDataDatabaseTransactionFactory
{
    Task<DataDatabaseTransaction> BeginTransactionAsync(CancellationToken cancellationToken);
}

public sealed class DataDatabaseTransactionFactory(
    AppDbContext dbContext,
    IConfiguration configuration) : IDataDatabaseTransactionFactory
{
    public async Task<DataDatabaseTransaction> BeginTransactionAsync(CancellationToken cancellationToken)
    {
        var appConnectionString = dbContext.Database.GetConnectionString();
        var dataConnectionString = DataDatabaseConnection.Resolve(
            configuration,
            appConnectionString);

        EnsureSameSqlServer(dataConnectionString, appConnectionString);
        var appDatabaseName = AppDatabaseName(appConnectionString);

        var connection = new SqlConnection(dataConnectionString);
        try
        {
            await connection.OpenAsync(cancellationToken);
            var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
            return new DataDatabaseTransaction(connection, transaction, appDatabaseName);
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }

    private static string? AppDatabaseName(string? connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return null;
        }

        var builder = new SqlConnectionStringBuilder(connectionString);
        return string.IsNullOrWhiteSpace(builder.InitialCatalog)
            ? null
            : builder.InitialCatalog;
    }

    private static void EnsureSameSqlServer(string dataConnectionString, string? appConnectionString)
    {
        if (string.IsNullOrWhiteSpace(appConnectionString))
        {
            return;
        }

        var dataBuilder = new SqlConnectionStringBuilder(dataConnectionString);
        var appBuilder = new SqlConnectionStringBuilder(appConnectionString);
        if (string.Equals(dataBuilder.DataSource, appBuilder.DataSource, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        throw new InvalidOperationException(
            "Cross-database transactions require the data database and app database connections to use the same SQL Server. " +
            "Use an outbox or reconciliation flow for cross-server writes.");
    }
}

public sealed class DataDatabaseTransaction : IAsyncDisposable
{
    internal DataDatabaseTransaction(
        SqlConnection connection,
        SqlTransaction transaction,
        string? appDatabaseName)
    {
        Connection = connection;
        Transaction = transaction;
        AppDatabaseName = appDatabaseName;
    }

    public SqlConnection Connection { get; }

    public SqlTransaction Transaction { get; }

    private string? AppDatabaseName { get; }

    public string QualifiedAppTableName(string tableName, string schema = AppDbContext.AppSchema)
    {
        var schemaAndTable = $"{QuoteIdentifier(schema)}.{QuoteIdentifier(tableName)}";

        return string.IsNullOrWhiteSpace(AppDatabaseName)
            ? schemaAndTable
            : $"{QuoteIdentifier(AppDatabaseName)}.{schemaAndTable}";
    }

    public Task CommitAsync(CancellationToken cancellationToken)
    {
        return Transaction.CommitAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await Transaction.DisposeAsync();
        await Connection.DisposeAsync();
    }

    public static string QuoteIdentifier(string identifier)
    {
        return $"[{identifier.Replace("]", "]]")}]";
    }
}
