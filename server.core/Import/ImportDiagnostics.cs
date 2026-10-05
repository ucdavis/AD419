using Microsoft.Extensions.Logging;
using Server.Core.Diagnostics;

namespace Server.Core.Import;

/// <summary>Phase telemetry only; does not change cancellation or transaction ownership.</summary>
public sealed class ImportDiagnostics : IDisposable
{
    private readonly ILogger _logger;
    private readonly OperationDiagnostics _operation;
    private bool _committed;

    public ImportDiagnostics(ILogger logger, string import, object? period = null, string? segment = null)
    {
        _logger = logger;
        _operation = new OperationDiagnostics(logger, "WarehouseImport", new Dictionary<string, object?>
        {
            ["Import"] = import,
            ["ReportingPeriod"] = period,
            ["Segment"] = segment,
        });
    }

    public Task RunAsync(string phase, Func<Task> action) =>
        _operation.RunAsync(phase, action, CommitFields());

    public Task<T> RunAsync<T>(string phase, Func<Task<T>> action) =>
        _operation.RunAsync(phase, action, CommitFields());

    public async Task CommitAsync(Func<Task> commit)
    {
        await RunAsync("Commit", commit);
        _committed = true;
        _logger.LogInformation("Data committed. DataCommitted={DataCommitted}, ElapsedMs={ElapsedMs}.",
            true, _operation.ElapsedMilliseconds);
    }

    public void Complete(long rows)
    {
        var fields = CommitFields();
        fields["RowsProcessed"] = rows;
        _operation.Complete(fields);
    }

    public static Task<T> PhaseAsync<T>(ILogger logger, string phase, Func<Task<T>> action, bool? committed = null) =>
        OperationDiagnostics.PhaseAsync(logger, phase, action,
            committed.HasValue ? new Dictionary<string, object?> { ["DataCommitted"] = committed.Value } : null);

    private Dictionary<string, object?> CommitFields() => new() { ["DataCommitted"] = _committed };

    public void Dispose() => _operation.Dispose();
}
