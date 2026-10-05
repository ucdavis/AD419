using System.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Server.Core.Diagnostics;

/// <summary>Operation telemetry only; does not own cancellation, transactions, or outcomes.</summary>
public sealed class OperationDiagnostics : IDisposable
{
    private readonly ILogger _logger;
    private readonly string _operation;
    private readonly IDisposable? _scope;
    private readonly Stopwatch _elapsed = Stopwatch.StartNew();

    public OperationDiagnostics(ILogger logger, string operation, IReadOnlyDictionary<string, object?>? context = null)
    {
        _logger = logger;
        _operation = operation;
        var fields = context is null ? new Dictionary<string, object?>() : new Dictionary<string, object?>(context);
        fields["Operation"] = operation;
        _scope = logger.BeginScope(fields);
        logger.LogInformation("Operation {Operation} started.", operation);
    }

    public long ElapsedMilliseconds => _elapsed.ElapsedMilliseconds;

    public Task RunAsync(string phase, Func<Task> action, IReadOnlyDictionary<string, object?>? fields = null) =>
        PhaseAsync(_logger, phase, action, fields);

    public Task<T> RunAsync<T>(string phase, Func<Task<T>> action, IReadOnlyDictionary<string, object?>? fields = null) =>
        PhaseAsync(_logger, phase, action, fields);

    public void Complete(IReadOnlyDictionary<string, object?>? fields = null)
    {
        using var scope = fields is null ? null : _logger.BeginScope(fields);
        _logger.LogInformation("Operation {Operation} completed. ElapsedMs={ElapsedMs}.", _operation, ElapsedMilliseconds);
    }

    public static async Task PhaseAsync(ILogger logger, string phase, Func<Task> action,
        IReadOnlyDictionary<string, object?>? fields = null)
    {
        await PhaseAsync(logger, phase, async () => { await action(); return true; }, fields);
    }

    public static async Task<T> PhaseAsync<T>(ILogger logger, string phase, Func<Task<T>> action,
        IReadOnlyDictionary<string, object?>? fields = null)
    {
        using var contextScope = fields is null ? null : logger.BeginScope(fields);
        using var phaseScope = logger.BeginScope(new Dictionary<string, object?> { ["Phase"] = phase });
        var elapsed = Stopwatch.StartNew();
        logger.LogInformation("Operation phase {Phase} started.", phase);
        try
        {
            var result = await action();
            logger.LogInformation("Operation phase {Phase} completed. ElapsedMs={ElapsedMs}.", phase, elapsed.ElapsedMilliseconds);
            return result;
        }
        catch (Exception ex)
        {
            // The request/job boundary owns the stack trace. Phase records supply context.
            logger.Log(ex is OperationCanceledException ? LogLevel.Warning : LogLevel.Error,
                "Operation phase {Phase} ended with {Outcome}. ElapsedMs={ElapsedMs}, ExceptionType={ExceptionType}.",
                phase, ex is OperationCanceledException ? "cancellation" : "failure",
                elapsed.ElapsedMilliseconds, ex.GetType().Name);
            throw;
        }
    }

    public void Dispose() => _scope?.Dispose();
}
