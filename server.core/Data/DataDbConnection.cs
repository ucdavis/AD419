using Microsoft.Extensions.Configuration;

namespace Server.Core.Data;

public static class DataDbConnection
{
    public const string EnvironmentVariableName = "DATA_DB_CONNECTION";
    public const string ConnectionStringName = "DataConnection";
    // The AE pull streams ~465k rows through the linked server's row-by-row ODBC
    // fetch, which takes over 10 minutes on its own; 600s timed out in practice.
    public const int ImportCommandTimeoutSeconds = 3600;

    public static string Resolve(IConfiguration configuration, string? fallbackConnectionString)
    {
        var connectionString = Coalesce(
            configuration[EnvironmentVariableName],
            configuration.GetConnectionString(ConnectionStringName),
            fallbackConnectionString);

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                $"No data database connection string configured. Set the {EnvironmentVariableName} environment variable " +
                $"or configure ConnectionStrings:{ConnectionStringName}.");
        }

        return connectionString;
    }

    private static string? Coalesce(params string?[] values)
    {
        return values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
    }
}
