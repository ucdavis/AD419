namespace Server.Helpers;

internal static class ApiOperationContext
{
    private static readonly object Key = new();
    private static readonly IReadOnlyDictionary<string, object?> Empty = new Dictionary<string, object?>();

    // Keep selected identifiers available after controller log scopes have unwound.
    public static void Set(HttpContext context, string operation, params (string Name, object? Value)[] identifiers)
    {
        var fields = new Dictionary<string, object?> { ["Operation"] = operation };
        foreach (var (name, value) in identifiers)
        {
            fields[name] = value;
        }
        context.Items[Key] = fields;
    }

    public static IReadOnlyDictionary<string, object?> Get(HttpContext context) =>
        context.Items.TryGetValue(Key, out var fields)
            ? (IReadOnlyDictionary<string, object?>)fields!
            : Empty;
}
