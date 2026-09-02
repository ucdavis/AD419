using Dapper;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.Controllers;
using Server.Core.Data;
using Server.Core.Domain;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.SegmentClassifications;
using Server.Tests.SqlIntegration;

namespace Server.Tests.SegmentClassifications;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class SegmentClassificationsControllerSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Patch_changed_classification_updates_row_and_invalidates_cache_status()
    {
        await fixture.ClearDataTablesAsync();
        await SeedClassificationAndCacheStatusAsync();

        await using var db = fixture.CreateDataDbContext();
        var controller = new SegmentClassificationsController(db, new ExpenseReviewCacheService(db, Configuration()));

        var result = await controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "201"),
            CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeTrue();
        updated.Sfn.Should().Be("201");
        (await CacheStatusCountAsync()).Should().Be(0);
    }

    [Fact]
    public async Task Patch_rolls_back_classification_when_cache_invalidation_fails()
    {
        await fixture.ClearDataTablesAsync();
        await SeedClassificationAndCacheStatusAsync();

        await using var db = fixture.CreateDataDbContext();
        var controller = new SegmentClassificationsController(db, new ThrowingExpenseReviewCacheService());

        var act = () => controller.UpdateClassification(
            new UpdateClassificationRequest("Fund", "70575", true, "201"),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Invalidation failed.");

        db.ChangeTracker.Clear();
        var updated = await db.SegmentClassifications.FindAsync(SegmentType.Fund, "70575");
        updated!.IncludeInReport.Should().BeNull();
        updated.Sfn.Should().Be("219");
        (await CacheStatusCountAsync()).Should().Be(1);
    }

    private async Task SeedClassificationAndCacheStatusAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Fund', '70575', 'Test Fund', NULL, '219');

            INSERT INTO [data].[ExpenseReviewCacheStatus]
                ([CycleStart], [CycleEnd], [RefreshedAt], [FactRowCount], [ReasonRowCount])
            VALUES
                ('2024-10-01', '2025-09-30', SYSUTCDATETIME(), 1, 0);
            """);
    }

    private async Task<int> CacheStatusCountAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        return await connection.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM [data].[ExpenseReviewCacheStatus];");
    }

    private IConfiguration Configuration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
            })
            .Build();

    private sealed class ThrowingExpenseReviewCacheService : IExpenseReviewCacheService
    {
        public Task EnsureCachePreparedAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        public Task ForceRefreshAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            Task.CompletedTask;

        public Task InvalidateAsync(CancellationToken cancellationToken) =>
            throw new InvalidOperationException("Invalidation failed.");
    }
}
