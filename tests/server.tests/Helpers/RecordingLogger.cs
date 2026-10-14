using Microsoft.Extensions.Logging;

namespace Server.Tests.Helpers;

internal sealed record LogEntry(LogLevel Level, string Message, Exception? Exception, Dictionary<string, object?> Fields);

internal sealed class RecordingLogger<T> : ILogger<T>
{
    private readonly LoggerExternalScopeProvider _scopes = new();
    public List<LogEntry> Entries { get; } = [];
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => _scopes.Push(state);
    public bool IsEnabled(LogLevel logLevel) => true;
    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
    {
        var fields = new Dictionary<string, object?>();
        _scopes.ForEachScope((scope, values) => AddFields(scope, values), fields);
        AddFields(state, fields);
        Entries.Add(new(logLevel, formatter(state, exception), exception, fields));
    }

    private static void AddFields(object? state, Dictionary<string, object?> fields)
    {
        if (state is IEnumerable<KeyValuePair<string, object?>> values)
        {
            foreach (var value in values) fields[value.Key] = value.Value;
        }
    }
}
