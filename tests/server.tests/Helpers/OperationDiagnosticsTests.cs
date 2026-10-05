using FluentAssertions;
using Microsoft.Extensions.Logging;
using Server.Core.Diagnostics;

namespace Server.Tests.Helpers;

public sealed class OperationDiagnosticsTests
{
    [Fact]
    public async Task Success_preserves_results_context_and_scope_lifetimes()
    {
        var logger = new RecordingLogger<OperationDiagnostics>();
        using (logger.BeginScope(new Dictionary<string, object?> { ["RequestId"] = 7 }))
        {
            using (var diagnostics = new OperationDiagnostics(logger, "Export",
                       new Dictionary<string, object?> { ["FiscalYear"] = "FY26" }))
            {
                var result = await diagnostics.RunAsync("Read rows", () => Task.FromResult(42),
                    new Dictionary<string, object?> { ["Table"] = "Projects" });
                result.Should().Be(42);
                var phase = logger.Entries.Last();
                phase.Fields.Should().Contain("Operation", "Export").And.Contain("FiscalYear", "FY26")
                    .And.Contain("RequestId", 7).And.Contain("Phase", "Read rows").And.Contain("Table", "Projects");
                ((long)phase.Fields["ElapsedMs"]!).Should().BeGreaterThanOrEqualTo(0);

                var written = false;
                await diagnostics.RunAsync("Write rows", () => { written = true; return Task.CompletedTask; });
                written.Should().BeTrue();
                logger.Entries.Last().Fields.Should().NotContainKey("Table");

                diagnostics.Complete(new Dictionary<string, object?> { ["RowsWritten"] = result });
                var completion = logger.Entries.Last();
                completion.Message.Should().StartWith("Operation Export completed.");
                completion.Fields.Should().Contain("RowsWritten", 42).And.NotContainKey("Phase");
                ((long)completion.Fields["ElapsedMs"]!).Should().BeGreaterThanOrEqualTo(0);
                diagnostics.ElapsedMilliseconds.Should().BeGreaterThanOrEqualTo(0);
            }
            logger.LogInformation("After operation");
            logger.Entries.Last().Fields.Should().Contain("RequestId", 7).And.NotContainKey("Operation")
                .And.NotContainKey("FiscalYear").And.NotContainKey("RowsWritten");
        }
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task Failure_preserves_original_exception_and_cleans_up_scopes(bool canceled, bool synchronous)
    {
        var logger = new RecordingLogger<OperationDiagnostics>();
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        Exception expected = canceled ? new OperationCanceledException(cancellation.Token) : new InvalidOperationException("private detail");
        using (var diagnostics = new OperationDiagnostics(logger, "Export"))
        {
            var actual = await Record.ExceptionAsync(() => diagnostics.RunAsync<int>("Read rows", () =>
                synchronous ? throw expected : Task.FromException<int>(expected)));
            actual.Should().BeSameAs(expected);
            var failure = logger.Entries.Last();
            failure.Level.Should().Be(canceled ? LogLevel.Warning : LogLevel.Error);
            failure.Exception.Should().BeNull();
            failure.Fields.Should().Contain("Outcome", canceled ? "cancellation" : "failure")
                .And.Contain("ExceptionType", expected.GetType().Name).And.Contain("Operation", "Export");
            ((long)failure.Fields["ElapsedMs"]!).Should().BeGreaterThanOrEqualTo(0);
            failure.Message.Should().NotContain("private detail");
            logger.LogInformation("After phase");
            logger.Entries.Last().Fields.Should().Contain("Operation", "Export").And.NotContainKey("Phase");
        }
        logger.Entries.Should().NotContain(e => e.Message.StartsWith("Operation Export completed"));
        logger.LogInformation("After disposal");
        logger.Entries.Last().Fields.Should().NotContainKey("Operation");
    }

    [Fact]
    public async Task Standalone_phases_support_both_delegate_shapes_without_creating_an_operation()
    {
        var logger = new RecordingLogger<OperationDiagnostics>();
        await OperationDiagnostics.PhaseAsync(logger, "Connect", () => Task.CompletedTask);
        var result = await OperationDiagnostics.PhaseAsync(logger, "Read", () => Task.FromResult(12),
            new Dictionary<string, object?> { ["Source"] = "Projects" });
        result.Should().Be(12);
        logger.Entries.Last().Fields.Should().Contain("Source", "Projects").And.NotContainKey("Operation");
        logger.LogInformation("After phase");
        logger.Entries.Last().Fields.Should().NotContainKey("Source").And.NotContainKey("Phase");
    }
}
