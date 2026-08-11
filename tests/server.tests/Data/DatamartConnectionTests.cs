using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;

namespace Server.Tests.Data;

public class DatamartConnectionTests
{
    [Fact]
    public void Resolve_prefers_environment_variable_over_named_connection()
    {
        var configuration = BuildConfiguration(new Dictionary<string, string?>
        {
            [DatamartConnection.EnvironmentVariableName] = "env-connection",
            [$"ConnectionStrings:{DatamartConnection.ConnectionStringName}"] = "named-connection",
        });

        var connectionString = DatamartConnection.Resolve(configuration);

        connectionString.Should().Be("env-connection");
    }

    [Fact]
    public void Resolve_skips_blank_environment_variable_and_uses_named_connection()
    {
        var configuration = BuildConfiguration(new Dictionary<string, string?>
        {
            [DatamartConnection.EnvironmentVariableName] = "   ",
            [$"ConnectionStrings:{DatamartConnection.ConnectionStringName}"] = "named-connection",
        });

        var connectionString = DatamartConnection.Resolve(configuration);

        connectionString.Should().Be("named-connection");
    }

    [Fact]
    public void Resolve_throws_when_nothing_is_configured()
    {
        var configuration = BuildConfiguration([]);

        var resolve = () => DatamartConnection.Resolve(configuration);

        resolve.Should().Throw<InvalidOperationException>()
            .WithMessage($"*{DatamartConnection.EnvironmentVariableName}*");
    }

    private static IConfiguration BuildConfiguration(Dictionary<string, string?> values)
    {
        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }
}
