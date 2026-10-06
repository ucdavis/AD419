using FluentAssertions;
using Microsoft.Extensions.Logging;
using Server.Core.Domain;
using Server.Core.Import;
using Server.Models.ImportRuns;
using Server.Tests.Helpers;

namespace Server.Tests.Import;

public sealed class ImportDiagnosticsTests
{
    [Fact]
    public async Task Completion_retains_import_context_row_count_and_confirmed_commit()
    {
        var logger = new RecordingLogger<ImportDiagnostics>();
        var period = new DateOnly(2025, 9, 30);
        using var diagnostics = new ImportDiagnostics(logger, "PGM", period, "Projects");
        await diagnostics.CommitAsync(() => Task.CompletedTask);
        diagnostics.Complete(42);
        var completion = logger.Entries.Last();
        completion.Message.Should().StartWith("Operation WarehouseImport completed.");
        completion.Fields.Should().Contain("Operation", "WarehouseImport").And.Contain("Import", "PGM")
            .And.Contain("ReportingPeriod", period).And.Contain("Segment", "Projects")
            .And.Contain("RowsProcessed", 42L).And.Contain("DataCommitted", true);
        logger.Entries.Should().ContainSingle(e => e.Message.StartsWith("Data committed."));
    }

    [Fact]
    public async Task Failed_commit_does_not_report_confirmed_commit()
    {
        var logger = new RecordingLogger<ImportDiagnostics>();
        using var diagnostics = new ImportDiagnostics(logger, "PGM");
        var expected = new InvalidOperationException("Commit failed");
        var actual = await Record.ExceptionAsync(() => diagnostics.CommitAsync(() => Task.FromException(expected)));
        actual.Should().BeSameAs(expected);
        var failure = logger.Entries.Last();
        failure.Fields.Should().Contain("Phase", "Commit").And.Contain("DataCommitted", false);
        await diagnostics.RunAsync("Inspect", () => Task.CompletedTask);
        logger.Entries.Last().Fields.Should().Contain("DataCommitted", false);
        logger.Entries.Should().NotContain(e => e.Message.StartsWith("Data committed."));
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task Phase_failure_records_commit_state_without_duplicate_stack(bool committed, bool canceled)
    {
        var logger = new RecordingLogger<ImportDiagnostics>();
        using var diagnostics = new ImportDiagnostics(logger, "PGM", new DateOnly(2025, 9, 30));
        if (committed) await diagnostics.CommitAsync(() => Task.CompletedTask);
        Exception exception = canceled ? new OperationCanceledException() : new InvalidOperationException("failure");
        var phase = committed ? "Aggregate checks" : "Source transfer";
        await FluentActions.Awaiting(() => diagnostics.RunAsync(phase, () => Task.FromException(exception)))
            .Should().ThrowAsync<Exception>();
        var failure = logger.Entries.Last();
        failure.Fields["Phase"].Should().Be(phase);
        failure.Fields["DataCommitted"].Should().Be(committed);
        failure.Fields["Import"].Should().Be("PGM");
        failure.Level.Should().Be(canceled ? LogLevel.Warning : LogLevel.Error);
        failure.Exception.Should().BeNull();
        logger.Entries.Any(e => e.Message.StartsWith("Data committed")).Should().Be(committed);
        logger.Entries.Should().NotContain(e => e.Message.Contains("rollback", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task Source_connection_failure_is_logged_without_query_parameters()
    {
        var logger = new RecordingLogger<LinkedServerQueryExecutor>();
        var executor = new LinkedServerQueryExecutor(logger);
        await FluentActions.Awaiting(() => executor.ExecuteReaderAsync("", "sensitive-query", [],
            (_, _) => Task.FromResult(0), CancellationToken.None)).Should().ThrowAsync<InvalidOperationException>();
        logger.Entries.Should().Contain(e => Equals(e.Fields.GetValueOrDefault("Phase"), "Source connection")
            && Equals(e.Fields.GetValueOrDefault("Outcome"), "failure"));
        logger.Entries.Should().NotContain(e => e.Message.Contains("sensitive-query"));
    }

    [Theory]
    [InlineData("SqlException: secret SQL\n at SomeMethod()", "This import step could not be completed. Contact support if the problem continues.")]
    [InlineData("Interrupted by application restart.", "Interrupted by application restart.")]
    [InlineData("Interrupted by application restart.\nSqlException: secret SQL", "This import step could not be completed. Contact support if the problem continues.")]
    public void Stage_error_mapping_only_returns_known_safe_details(string errorDetail, string expectedErrorDetail)
    {
        var run = new ImportRun
        {
            Stages = [new ImportRunStage { Name = "AE", Status = ImportStageStatus.Failed, ErrorDetail = errorDetail }],
        };
        var dto = ImportRunDto.From(run);
        dto.Stages.Single().ErrorDetail.Should().Be(expectedErrorDetail);
        run.Stages.Single().ErrorDetail.Should().Be(errorDetail);
    }
}
