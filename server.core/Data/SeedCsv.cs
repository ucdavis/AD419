namespace Server.Core.Data;

/// <summary>
/// Reads embedded CSV seed resources (server.core/Data/Seed/*.csv). Rows are split on
/// commas (the seed exports contain no embedded commas); the header is skipped and
/// blank lines are ignored.
/// </summary>
public static class SeedCsv
{
    public static List<T> ReadRows<T>(string fileName, Func<string[], T> map)
    {
        using var stream = OpenResource(fileName);
        using var reader = new StreamReader(stream);
        var rows = new List<T>();
        var isHeader = true;
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            if (isHeader) { isHeader = false; continue; }
            if (string.IsNullOrWhiteSpace(line)) { continue; }
            rows.Add(map(line.Split(',')));
        }

        return rows;
    }

    public static string? Nullable(string value)
    {
        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }

    private static Stream OpenResource(string fileName)
    {
        var assembly = typeof(SeedCsv).Assembly;
        var name = assembly.GetManifestResourceNames()
            .Single(candidate => candidate.EndsWith(fileName, StringComparison.Ordinal));
        return assembly.GetManifestResourceStream(name)
            ?? throw new InvalidOperationException($"Embedded seed resource '{fileName}' was not found.");
    }
}
