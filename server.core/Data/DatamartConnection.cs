using Microsoft.Extensions.Configuration;

namespace Server.Core.Data;

public static class DatamartConnection
{
    public const string EnvironmentVariableName = "DATAMART_CONNECTION";
    public const string ConnectionStringName = "Datamart";

    public static string Resolve(IConfiguration configuration)
    {
        var environmentValue = configuration[EnvironmentVariableName];
        var connectionString = string.IsNullOrWhiteSpace(environmentValue)
            ? configuration.GetConnectionString(ConnectionStringName)
            : environmentValue;

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                $"No datamart connection string configured. Set the {EnvironmentVariableName} environment variable " +
                $"or configure ConnectionStrings:{ConnectionStringName}.");
        }

        return connectionString;
    }
}
