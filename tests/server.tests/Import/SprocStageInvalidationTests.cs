using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.Core.Import;
using Server.Models;
using Server.ProjectList;
using Server.Tests.Helpers;
using Server.Tests.SqlIntegration;

namespace Server.Tests.Import;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class SprocStageInvalidationTests(SqlServerDataDbFixture fixture)
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Both_project_build_paths_invalidate_only_after_a_successful_commit(bool importStage)
    {
        await fixture.ClearDataTablesAsync();
        await using var db = fixture.CreateDataDbContext();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var stages = new SprocStageService(db, Configuration(), invalidator);
        var projects = new ProjectListService(db, Configuration(), invalidator);
        var cycle = new FiscalYearCycle("FY25", new(2024, 10, 1), new(2025, 9, 30));

        async Task BuildAsync()
        {
            if (importStage)
            {
                await stages.BuildProjectsAsync(cycle.CycleStart, cycle.CycleEnd, CancellationToken.None);
            }
            else
            {
                await projects.BuildProjectsAsync(cycle, CancellationToken.None);
            }
        }

        await FluentActions.Awaiting(BuildAsync).Should().ThrowAsync<SqlException>();
        invalidator.Calls.Should().Be(0, "the readiness guard rejected the build");

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ActiveProjects]
                ([ProjectNumber], [AccessionNumber], [UcpEmployeeId], [UcPathName], [Is204],
                 [ExcludeFromUi], [ProjectDirector], [PdEmailAddress])
            VALUES ('EXCLUDED-H', 'A000001', '10000001', 'Test Person', 0, 1, 'Test PI', 'test@example.test');
            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn])
            VALUES ('OLD0001', 'OLD-H', 0, '201');
            """);

        await connection.ExecuteAsync("""
            CREATE TRIGGER [data].[RejectProjectRebuild] ON [data].[Projects] AFTER DELETE
            AS THROW 50001, 'Simulated rebuild failure.', 1;
            """);
        try
        {
            await FluentActions.Awaiting(BuildAsync).Should().ThrowAsync<SqlException>();
            invalidator.Calls.Should().Be(0, "the rebuild rolled back");
            (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[Projects];")).Should().Be(1);
        }
        finally
        {
            await connection.ExecuteAsync("DROP TRIGGER [data].[RejectProjectRebuild];");
        }

        await BuildAsync();

        invalidator.Calls.Should().Be(1);
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[Projects];")).Should().Be(0);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Seeding_and_classification_invalidate_successful_execution(bool classification)
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.ExecuteAsync("INSERT INTO [data].[ChartSegments] ([SegmentName], [Code]) VALUES ('Account', 'A1');");
        await using var db = fixture.CreateDataDbContext();
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var service = new SprocStageService(db, Configuration(), invalidator);

        if (classification)
        {
            await service.ClassifyTransactionsAsync(new(2024, 10, 1), new(2025, 9, 30), CancellationToken.None);
        }
        else
        {
            await service.SeedSegmentClassificationsAsync(CancellationToken.None);
        }

        invalidator.Calls.Should().Be(1);
    }

    [Fact]
    public async Task Classification_validation_rejection_also_invalidates()
    {
        await fixture.ClearDataTablesAsync();
        await using var db = fixture.CreateDataDbContext();
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var service = new SprocStageService(db, Configuration(), invalidator);

        await FluentActions.Awaiting(() => service.ClassifyTransactionsAsync(
            new(2024, 10, 1), new(2025, 9, 30), CancellationToken.None)).Should().ThrowAsync<SqlException>();

        invalidator.Calls.Should().Be(1);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Partial_sproc_failure_still_invalidates_committed_writes(bool classification)
    {
        await fixture.ClearDataTablesAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code]) VALUES ('Account', 'A1');
            INSERT INTO [data].[AETransactions] ([Fund], [PeriodName], [ExcludedByDate]) VALUES ('F1', 'Oct-24', 1);
            """);
        var table = classification ? "UcPathTransactions" : "SegmentClassifications";
        await connection.ExecuteAsync($"""
            CREATE TRIGGER [data].[FailAfterEarlierCommit] ON [data].[{table}] AFTER UPDATE
            AS THROW 50000, 'Simulated failure after an earlier committed statement.', 1;
            """);
        try
        {
            await using var db = fixture.CreateDataDbContext();
            var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
            var service = new SprocStageService(db, Configuration(), invalidator);
            Func<Task> execute = classification
                ? async () => await service.ClassifyTransactionsAsync(new(2024, 10, 1), new(2025, 9, 30), CancellationToken.None)
                : async () => await service.SeedSegmentClassificationsAsync(CancellationToken.None);

            await FluentActions.Awaiting(execute).Should().ThrowAsync<SqlException>();

            invalidator.Calls.Should().Be(1);
            if (classification)
            {
                (await connection.ExecuteScalarAsync<bool>("SELECT [ExcludedByDate] FROM [data].[AETransactions];"))
                    .Should().BeFalse("the first update committed before the later failure");
            }
            else
            {
                (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[SegmentClassifications] WHERE [Code] = 'F1';"))
                    .Should().Be(1, "the insert committed before the later failure");
            }
        }
        finally
        {
            await connection.ExecuteAsync("DROP TRIGGER [data].[FailAfterEarlierCommit];");
        }
    }

    private IConfiguration Configuration() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
        }).Build();
}
