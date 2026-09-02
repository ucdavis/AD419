using System.Diagnostics;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Testcontainers.MsSql;

namespace Server.Tests.SqlIntegration;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class SqlIntegrationCollection : ICollectionFixture<SqlServerDataDbFixture>
{
    public const string Name = "SqlIntegration";
}

public sealed class SqlServerDataDbFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        try
        {
            await _container.StartAsync();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            throw new InvalidOperationException(
                "SQL integration tests require Docker to be running so Testcontainers can start SQL Server.",
                ex);
        }

        var databaseName = $"AD419_Test_{Guid.NewGuid():N}";
        var builder = new SqlConnectionStringBuilder(_container.GetConnectionString())
        {
            InitialCatalog = databaseName,
            Encrypt = false,
            TrustServerCertificate = true,
        };
        ConnectionString = builder.ConnectionString;

        await PublishDataDacpacAsync(ConnectionString);
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }

    public DataDbContext CreateDataDbContext()
    {
        var options = new DbContextOptionsBuilder<DataDbContext>()
            .UseSqlServer(ConnectionString)
            .EnableSensitiveDataLogging()
            .Options;

        return new DataDbContext(options);
    }

    public async Task ClearDataTablesAsync()
    {
        await using var connection = new SqlConnection(ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            DELETE FROM [data].[ExpenseReviewTransactionReasons];
            DELETE FROM [data].[ExpenseReviewTransactionFacts];
            DELETE FROM [data].[ExpenseReviewCacheStatus];
            DELETE FROM [data].[Projects];
            DELETE FROM [data].[AETransactions];
            DELETE FROM [data].[UcPathTransactions];
            DELETE FROM [data].[SegmentClassifications];
            DELETE FROM [data].[ChartSegments];
            DELETE FROM [data].[ActiveProjects];
            DELETE FROM [data].[PGMProjects];
            DELETE FROM [data].[AllProjects];
            DELETE FROM [data].[AssistanceListingNumbers];
            DELETE FROM [data].[Sfns];
            """);
    }

    private static async Task PublishDataDacpacAsync(string connectionString)
    {
        var dacpac = ResolveDataDacpac();
        var sqlpackage = ResolveSqlPackage();

        using var process = new Process();
        process.StartInfo.FileName = sqlpackage;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        process.StartInfo.ArgumentList.Add("/Action:Publish");
        process.StartInfo.ArgumentList.Add($"/SourceFile:{dacpac}");
        process.StartInfo.ArgumentList.Add($"/TargetConnectionString:{connectionString}");
        process.StartInfo.ArgumentList.Add("/p:DropObjectsNotInSource=True");
        process.StartInfo.ArgumentList.Add("/p:BlockOnPossibleDataLoss=True");
        process.StartInfo.ArgumentList.Add("/p:CreateNewDatabase=True");
        process.StartInfo.ArgumentList.Add("/p:ScriptDatabaseOptions=False");

        if (!process.Start())
        {
            throw new InvalidOperationException("Unable to start sqlpackage.");
        }

        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        var stdout = await stdoutTask;
        var stderr = await stderrTask;

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"sqlpackage failed while publishing the data DACPAC.{Environment.NewLine}{stdout}{Environment.NewLine}{stderr}");
        }
    }

    private static string ResolveSqlPackage()
    {
        var configured = Environment.GetEnvironmentVariable("SQLPACKAGE");
        if (!string.IsNullOrWhiteSpace(configured))
        {
            return configured;
        }

        const string defaultPath = "/usr/local/sqlpackage/sqlpackage";
        return File.Exists(defaultPath) ? defaultPath : "sqlpackage";
    }

    private static string ResolveDataDacpac()
    {
        var root = RepositoryRoot();
        var configuration = Environment.GetEnvironmentVariable("BUILD_CONFIGURATION");
        var testConfiguration = InferTestConfiguration();
        var candidates = new[]
        {
            string.IsNullOrWhiteSpace(configuration)
                ? null
                : Path.Combine(root, "database", "data", "bin", configuration, "data.dacpac"),
            string.IsNullOrWhiteSpace(testConfiguration)
                ? null
                : Path.Combine(root, "database", "data", "bin", testConfiguration, "data.dacpac"),
            Path.Combine(root, "database", "data", "bin", "Debug", "data.dacpac"),
            Path.Combine(root, "database", "data", "bin", "Release", "data.dacpac"),
        };

        var dacpac = candidates.FirstOrDefault(path => path is not null && File.Exists(path));
        if (dacpac is not null)
        {
            return dacpac;
        }

        throw new InvalidOperationException(
            "The data DACPAC was not found. Build database/data/data.sqlproj before running SQL integration tests.");
    }

    private static string? InferTestConfiguration()
    {
        var segments = AppContext.BaseDirectory
            .Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

        for (var i = 0; i < segments.Length - 1; i++)
        {
            if (segments[i] == "bin")
            {
                return segments[i + 1];
            }
        }

        return null;
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "app.sln")))
        {
            directory = directory.Parent;
        }

        if (directory is null)
        {
            throw new InvalidOperationException("The AD419 repository root could not be resolved from the test output path.");
        }

        return directory.FullName;
    }
}
