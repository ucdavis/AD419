using Microsoft.Extensions.Configuration;

namespace Server.Core.Data;

public static class DataDbConnection
{
    public const string EnvironmentVariableName = "DATA_DB_CONNECTION";
    public const string ConnectionStringName = "DataConnection";

    public static string Resolve(IConfiguration configuration, string? fallbackConnectionString)
    {
        var connectionString = configuration[EnvironmentVariableName]
            ?? configuration.GetConnectionString(ConnectionStringName)
            ?? fallbackConnectionString;

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                $"No data database connection string configured. Set the {EnvironmentVariableName} environment variable " +
                $"or configure ConnectionStrings:{ConnectionStringName}.");
        }

        return connectionString;
    }
}
