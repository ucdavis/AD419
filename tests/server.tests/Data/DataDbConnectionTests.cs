using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;

namespace Server.Tests.Data;

public class DataDbConnectionTests
{
    [Fact]
    public void Resolve_skips_blank_environment_variable_and_uses_named_connection()
    {
        var configuration = BuildConfiguration(new Dictionary<string, string?>
        {
            [DataDbConnection.EnvironmentVariableName] = "   ",
            [$"ConnectionStrings:{DataDbConnection.ConnectionStringName}"] = "named-connection",
        });

        var connectionString = DataDbConnection.Resolve(configuration, "fallback-connection");

        connectionString.Should().Be("named-connection");
    }

    [Fact]
    public void Resolve_skips_blank_configured_connections_and_uses_fallback()
    {
        var configuration = BuildConfiguration(new Dictionary<string, string?>
        {
            [DataDbConnection.EnvironmentVariableName] = "   ",
            [$"ConnectionStrings:{DataDbConnection.ConnectionStringName}"] = "\t",
        });

        var connectionString = DataDbConnection.Resolve(configuration, "fallback-connection");

        connectionString.Should().Be("fallback-connection");
    }

    private static IConfiguration BuildConfiguration(Dictionary<string, string?> values)
    {
        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }
}
