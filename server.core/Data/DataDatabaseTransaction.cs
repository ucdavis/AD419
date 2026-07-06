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
        var dataConnectionString = DataDatabaseConnection.Resolve(
            configuration,
            dbContext.Database.GetConnectionString());

        var connection = new SqlConnection(dataConnectionString);
        try
        {
            await connection.OpenAsync(cancellationToken);
            var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);
            return new DataDatabaseTransaction(connection, transaction);
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
    }
}

public sealed class DataDatabaseTransaction : IAsyncDisposable
{
    internal DataDatabaseTransaction(
        SqlConnection connection,
        SqlTransaction transaction)
    {
        Connection = connection;
        Transaction = transaction;
    }

    public SqlConnection Connection { get; }

    public SqlTransaction Transaction { get; }

    public Task CommitAsync(CancellationToken cancellationToken)
    {
        return Transaction.CommitAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            await Transaction.DisposeAsync();
        }
        finally
        {
            await Connection.DisposeAsync();
        }
    }
}
