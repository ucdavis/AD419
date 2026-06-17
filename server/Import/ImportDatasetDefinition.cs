using System.Text.RegularExpressions;

namespace Server.Import;

public enum ImportColumnType
{
    String,
    Boolean,
    Decimal,
    Date,
    Int16,
}

public sealed record ImportColumn(
    string TargetColumn,
    ImportColumnType Type,
    bool Required,
    int? MaxLength,
    IReadOnlyList<string> SourceHeaders);

public sealed record ImportUniqueKey(string Name, IReadOnlyList<string> Columns);

public sealed partial class ImportDatasetDefinition
{
    private readonly Dictionary<string, ImportColumn> columnsByNormalizedHeader;

    public ImportDatasetDefinition(
        string id,
        string displayName,
        string schemaName,
        string tableName,
        IReadOnlyList<ImportColumn> columns,
        IReadOnlyList<ImportUniqueKey> uniqueKeys)
    {
        Id = id;
        DisplayName = displayName;
        SchemaName = schemaName;
        TableName = tableName;
        Columns = columns;
        UniqueKeys = uniqueKeys;

        columnsByNormalizedHeader = [];
        var normalizedHeaderSources = new Dictionary<string, (ImportColumn Column, string SourceHeader)>();
        foreach (var column in columns)
        {
            foreach (var sourceHeader in column.SourceHeaders.Append(column.TargetColumn))
            {
                var normalized = NormalizeHeader(sourceHeader);
                if (!string.IsNullOrWhiteSpace(normalized))
                {
                    if (normalizedHeaderSources.TryGetValue(normalized, out var existing))
                    {
                        if (!ReferenceEquals(existing.Column, column))
                        {
                            throw new InvalidOperationException(
                                $"Normalized header '{normalized}' from source '{sourceHeader}' in column '{column.TargetColumn}' " +
                                $"conflicts with source '{existing.SourceHeader}' in column '{existing.Column.TargetColumn}'.");
                        }

                        continue;
                    }

                    normalizedHeaderSources[normalized] = (column, sourceHeader);
                    columnsByNormalizedHeader[normalized] = column;
                }
            }
        }
    }

    public string Id { get; }
    public string DisplayName { get; }
    public string SchemaName { get; }
    public string TableName { get; }
    public IReadOnlyList<ImportColumn> Columns { get; }
    public IReadOnlyList<ImportUniqueKey> UniqueKeys { get; }

    public ImportColumn? FindColumnBySourceHeader(string sourceHeader)
    {
        var normalized = NormalizeHeader(sourceHeader);
        return columnsByNormalizedHeader.GetValueOrDefault(normalized);
    }

    public static string NormalizeHeader(string value)
    {
        return HeaderNormalizer().Replace(value.Trim().ToLowerInvariant(), "");
    }

    [GeneratedRegex("[^a-z0-9]")]
    private static partial Regex HeaderNormalizer();
}
