using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using System.Transactions;

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
        var scope = new TransactionScope(
            TransactionScopeOption.Required,
            new TransactionOptions { IsolationLevel = IsolationLevel.ReadCommitted },
            TransactionScopeAsyncFlowOption.Enabled);

        var connection = new SqlConnection(dataConnectionString);
        try
        {
            await connection.OpenAsync(cancellationToken);
            return new DataDatabaseTransaction(scope, connection);
        }
        catch
        {
            await connection.DisposeAsync();
            scope.Dispose();
            throw;
        }
    }
}

public sealed class DataDatabaseTransaction : IAsyncDisposable
{
    internal DataDatabaseTransaction(
        TransactionScope scope,
        SqlConnection connection)
    {
        Scope = scope;
        Connection = connection;
    }

    public SqlConnection Connection { get; }

    private TransactionScope Scope { get; }

    public void Complete()
    {
        Scope.Complete();
    }

    public async ValueTask DisposeAsync()
    {
        await Connection.DisposeAsync();
        Scope.Dispose();
    }
}
