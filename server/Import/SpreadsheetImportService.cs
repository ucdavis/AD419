using System.Data;
using System.Security.Claims;
using System.Text.Json;
using ClosedXML.Excel;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Authorization;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.Imports;

namespace Server.Import;

public interface ISpreadsheetImportService
{
    Task<ImportResult> ImportAsync(
        string datasetId,
        IFormFile? file,
        ClaimsPrincipal? user,
        CancellationToken cancellationToken);
}

public abstract record ImportResult;

public sealed record ImportSucceeded(ImportSuccessResponse Response) : ImportResult;

public sealed record ImportValidationFailed(ImportValidationResponse Response) : ImportResult;

public sealed class SpreadsheetImportService(
    AppDbContext dbContext,
    ISpreadsheetImportRegistry registry,
    ILogger<SpreadsheetImportService> logger) : ISpreadsheetImportService
{
    private const string TempTableName = "#SpreadsheetImportRows";
    private const string StatusSucceeded = "Succeeded";
    private const string StatusValidationFailed = "ValidationFailed";
    private const string StatusPersistenceFailed = "PersistenceFailed";

    public async Task<ImportResult> ImportAsync(
        string datasetId,
        IFormFile? file,
        ClaimsPrincipal? user,
        CancellationToken cancellationToken)
    {
        var startedAt = DateTimeOffset.UtcNow;
        var definition = registry.Find(datasetId);
        if (definition is null)
        {
            return await ValidationAsync(datasetId, file?.FileName, 0,
                [new ImportFileError("unknown_dataset", $"Unknown import dataset '{datasetId}'.")],
                [],
                user,
                startedAt,
                cancellationToken);
        }

        var fileErrors = ValidateFile(file);
        if (fileErrors.Count > 0)
        {
            return await ValidationAsync(definition.Id, file?.FileName, 0, fileErrors, [], user, startedAt, cancellationToken);
        }

        var parseResult = ParseWorkbook(definition, file!);
        if (parseResult.FileErrors.Count > 0 || parseResult.Rows.Any(row => row.Errors.Count > 0 || row.CellErrors.Count > 0))
        {
            return await ValidationAsync(
                definition.Id,
                file!.FileName,
                parseResult.Rows.Count,
                parseResult.FileErrors,
                parseResult.Rows,
                user,
                startedAt,
                cancellationToken);
        }

        try
        {
            await ReplaceTargetTableAsync(definition, parseResult.ParsedRows, cancellationToken);
        }
        catch (StagingValidationException ex)
        {
            logger.LogWarning(ex, "Import staging validation failed for dataset {DatasetId}.", definition.Id);

            return await ValidationAsync(definition.Id, file!.FileName, parseResult.Rows.Count,
                [new ImportFileError("staging_validation_failed", "The import failed database validation. Existing data was not changed.")],
                parseResult.Rows,
                user,
                startedAt,
                cancellationToken,
                StatusPersistenceFailed);
        }
        catch (Exception ex) when (ex is SqlException or InvalidOperationException)
        {
            logger.LogWarning(ex, "Import persistence failed for dataset {DatasetId}.", definition.Id);

            var failedRows = parseResult.Rows.Count > 0
                ? parseResult.Rows
                : [new ImportRowResult(0, [], ["The database rejected the import before any rows were replaced."], [])];

            return await ValidationAsync(definition.Id, file!.FileName, parseResult.Rows.Count,
                [new ImportFileError("database_validation_failed", "The database rejected the import. Existing data was not changed.")],
                failedRows,
                user,
                startedAt,
                cancellationToken,
                StatusPersistenceFailed);
        }

        var importLogId = await LogImportAttemptAsync(
            definition.Id,
            file!.FileName,
            parseResult.Rows.Count,
            parseResult.Rows.Count,
            StatusSucceeded,
            null,
            user,
            startedAt,
            cancellationToken);

        return new ImportSucceeded(new ImportSuccessResponse(
            definition.Id,
            file!.FileName,
            parseResult.Rows.Count,
            importLogId,
            DateTimeOffset.UtcNow));
    }

    private static List<ImportFileError> ValidateFile(IFormFile? file)
    {
        var errors = new List<ImportFileError>();

        if (file is null)
        {
            errors.Add(new ImportFileError("missing_file", "Choose an .xlsx file to import."));
            return errors;
        }

        if (file.Length == 0)
        {
            errors.Add(new ImportFileError("empty_file", "The selected file is empty."));
        }

        if (!string.Equals(Path.GetExtension(file.FileName), ".xlsx", StringComparison.OrdinalIgnoreCase))
        {
            errors.Add(new ImportFileError("invalid_file_type", "Only .xlsx files can be imported."));
        }

        return errors;
    }

    private static WorkbookParseResult ParseWorkbook(ImportDatasetDefinition definition, IFormFile file)
    {
        using var stream = file.OpenReadStream();
        using var workbook = new XLWorkbook(stream);
        var worksheet = workbook.Worksheets.FirstOrDefault();

        if (worksheet is null)
        {
            return new WorkbookParseResult(
                [new ImportFileError("missing_headers", "The workbook does not contain a header row.")],
                [],
                []);
        }

        var headerRow = worksheet.FirstRowUsed();
        if (headerRow is null)
        {
            return new WorkbookParseResult(
                [new ImportFileError("missing_headers", "The workbook does not contain a header row.")],
                [],
                []);
        }

        var headerRowNumber = headerRow.RowNumber();
        var lastHeaderCell = headerRow.LastCellUsed();
        if (lastHeaderCell is null)
        {
            return new WorkbookParseResult(
                [new ImportFileError("missing_headers", "The workbook does not contain a header row.")],
                [],
                []);
        }

        var fileErrors = new List<ImportFileError>();
        var headersByColumnNumber = MapHeaders(definition, headerRow, lastHeaderCell.Address.ColumnNumber, fileErrors);
        foreach (var requiredColumn in definition.Columns.Where(column => column.Required))
        {
            if (!headersByColumnNumber.Values.Any(header => header.Column.TargetColumn == requiredColumn.TargetColumn))
            {
                fileErrors.Add(new ImportFileError(
                    "missing_required_header",
                    $"Missing required header for {requiredColumn.TargetColumn}.",
                    TargetColumn: requiredColumn.TargetColumn));
            }
        }

        if (fileErrors.Count > 0)
        {
            return new WorkbookParseResult(fileErrors, [], []);
        }

        var lastRow = worksheet.LastRowUsed()?.RowNumber() ?? headerRowNumber;
        var rows = new List<ImportRowResult>();
        var parsedRows = new List<ParsedImportRow>();

        for (var rowNumber = headerRowNumber + 1; rowNumber <= lastRow; rowNumber++)
        {
            var worksheetRow = worksheet.Row(rowNumber);
            if (IsBlankRow(worksheetRow, headersByColumnNumber.Keys))
            {
                continue;
            }

            var parsedRow = ParseRow(definition, worksheetRow, rowNumber, headersByColumnNumber);
            rows.Add(parsedRow.Result);
            parsedRows.Add(parsedRow);
        }

        if (rows.Count == 0)
        {
            fileErrors.Add(new ImportFileError("no_data_rows", "The workbook does not contain any data rows to import."));
            return new WorkbookParseResult(fileErrors, rows, parsedRows);
        }

        AddDuplicateKeyErrors(definition, parsedRows);

        return new WorkbookParseResult(fileErrors, rows, parsedRows);
    }

    private static Dictionary<int, HeaderBinding> MapHeaders(
        ImportDatasetDefinition definition,
        IXLRow headerRow,
        int lastColumnNumber,
        List<ImportFileError> fileErrors)
    {
        var bindings = new Dictionary<int, HeaderBinding>();
        var seenHeaders = new Dictionary<string, string>();
        var seenTargetColumns = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        for (var columnNumber = 1; columnNumber <= lastColumnNumber; columnNumber++)
        {
            var sourceHeader = headerRow.Cell(columnNumber).GetString().Trim();
            if (string.IsNullOrWhiteSpace(sourceHeader))
            {
                continue;
            }

            var normalized = ImportDatasetDefinition.NormalizeHeader(sourceHeader);
            if (seenHeaders.TryGetValue(normalized, out var originalHeader))
            {
                fileErrors.Add(new ImportFileError(
                    "duplicate_header",
                    $"Duplicate header '{sourceHeader}' also appears as '{originalHeader}'.",
                    sourceHeader));
                continue;
            }

            seenHeaders[normalized] = sourceHeader;

            var column = definition.FindColumnBySourceHeader(sourceHeader);
            if (column is null)
            {
                fileErrors.Add(new ImportFileError(
                    "unknown_header",
                    $"Header '{sourceHeader}' is not recognized for {definition.DisplayName}.",
                    sourceHeader));
                continue;
            }

            if (seenTargetColumns.TryGetValue(column.TargetColumn, out var originalSourceHeader))
            {
                fileErrors.Add(new ImportFileError(
                    "duplicate_target_header",
                    $"Headers '{originalSourceHeader}' and '{sourceHeader}' both map to {column.TargetColumn}.",
                    sourceHeader,
                    column.TargetColumn));
                continue;
            }

            seenTargetColumns[column.TargetColumn] = sourceHeader;
            bindings[columnNumber] = new HeaderBinding(sourceHeader, column);
        }

        return bindings;
    }

    private static bool IsBlankRow(IXLRow row, IEnumerable<int> columnNumbers)
    {
        return columnNumbers.All(columnNumber => string.IsNullOrWhiteSpace(row.Cell(columnNumber).GetString()));
    }

    private static ParsedImportRow ParseRow(
        ImportDatasetDefinition definition,
        IXLRow worksheetRow,
        int rowNumber,
        IReadOnlyDictionary<int, HeaderBinding> headersByColumnNumber)
    {
        var values = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        var parsedValues = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        var sourceHeaders = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        var rowErrors = new List<string>();
        var cellErrors = new List<ImportCellError>();

        foreach (var binding in headersByColumnNumber.Values)
        {
            values[binding.Column.TargetColumn] = null;
            sourceHeaders[binding.Column.TargetColumn] = binding.SourceHeader;
        }

        foreach (var (columnNumber, binding) in headersByColumnNumber)
        {
            var cell = worksheetRow.Cell(columnNumber);
            var rawValue = cell.GetFormattedString().Trim();
            values[binding.Column.TargetColumn] = rawValue;

            var parsed = ParseCell(cell, rawValue, binding.Column, binding.SourceHeader);
            if (parsed.Error is not null)
            {
                cellErrors.Add(parsed.Error);
            }

            parsedValues[binding.Column.TargetColumn] = parsed.Value;
        }

        foreach (var column in definition.Columns.Where(column => column.Required))
        {
            if (!parsedValues.TryGetValue(column.TargetColumn, out var value) || IsMissing(value))
            {
                var sourceHeader = headersByColumnNumber.Values
                    .FirstOrDefault(header => header.Column.TargetColumn == column.TargetColumn)?.SourceHeader;
                cellErrors.Add(new ImportCellError(
                    column.TargetColumn,
                    sourceHeader,
                    "required",
                    $"{column.TargetColumn} is required.",
                    values.GetValueOrDefault(column.TargetColumn)));
            }
        }

        var result = new ImportRowResult(rowNumber, values, rowErrors, cellErrors);
        return new ParsedImportRow(rowNumber, result, parsedValues, sourceHeaders);
    }

    private static ParsedCell ParseCell(IXLCell cell, string rawValue, ImportColumn column, string sourceHeader)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return new ParsedCell(null, null);
        }

        switch (column.Type)
        {
            case ImportColumnType.String:
                return ParseString(rawValue, column, sourceHeader);
            case ImportColumnType.Boolean:
                return ParseBoolean(cell, rawValue, column, sourceHeader);
            case ImportColumnType.Decimal:
                return ParseDecimal(cell, rawValue, column, sourceHeader);
            case ImportColumnType.Date:
                return ParseDate(cell, rawValue, column, sourceHeader);
            case ImportColumnType.Int16:
                return ParseInt16(cell, rawValue, column, sourceHeader);
            default:
                throw new ArgumentOutOfRangeException(nameof(column), column.Type, "Unsupported import column type.");
        }
    }

    private static ParsedCell ParseString(string rawValue, ImportColumn column, string sourceHeader)
    {
        if (column.MaxLength is not null && rawValue.Length > column.MaxLength.Value)
        {
            return new ParsedCell(rawValue, new ImportCellError(
                column.TargetColumn,
                sourceHeader,
                "max_length",
                $"{column.TargetColumn} must be {column.MaxLength.Value} characters or fewer.",
                rawValue));
        }

        return new ParsedCell(rawValue, null);
    }

    private static ParsedCell ParseBoolean(IXLCell cell, string rawValue, ImportColumn column, string sourceHeader)
    {
        if (cell.TryGetValue<bool>(out var boolValue))
        {
            return new ParsedCell(boolValue, null);
        }

        var normalized = rawValue.Trim().ToLowerInvariant();
        if (normalized is "true" or "yes" or "y" or "1" or "x")
        {
            return new ParsedCell(true, null);
        }

        if (normalized is "false" or "no" or "n" or "0")
        {
            return new ParsedCell(false, null);
        }

        return ConversionError(column, sourceHeader, rawValue, "a yes/no value");
    }

    private static ParsedCell ParseDecimal(IXLCell cell, string rawValue, ImportColumn column, string sourceHeader)
    {
        if (cell.TryGetValue<decimal>(out var decimalValue) ||
            decimal.TryParse(rawValue, out decimalValue))
        {
            return new ParsedCell(decimalValue, null);
        }

        return ConversionError(column, sourceHeader, rawValue, "a decimal number");
    }

    private static ParsedCell ParseDate(IXLCell cell, string rawValue, ImportColumn column, string sourceHeader)
    {
        if (cell.TryGetValue<DateTime>(out var dateValue) ||
            DateTime.TryParse(rawValue, out dateValue))
        {
            return new ParsedCell(DateOnly.FromDateTime(dateValue), null);
        }

        return ConversionError(column, sourceHeader, rawValue, "a date");
    }

    private static ParsedCell ParseInt16(IXLCell cell, string rawValue, ImportColumn column, string sourceHeader)
    {
        if (cell.TryGetValue<short>(out var shortValue) ||
            short.TryParse(rawValue, out shortValue))
        {
            return new ParsedCell(shortValue, null);
        }

        return ConversionError(column, sourceHeader, rawValue, "a whole number");
    }

    private static ParsedCell ConversionError(ImportColumn column, string sourceHeader, string rawValue, string expected)
    {
        return new ParsedCell(null, new ImportCellError(
            column.TargetColumn,
            sourceHeader,
            "type_conversion",
            $"{column.TargetColumn} must be {expected}.",
            rawValue));
    }

    private static void AddDuplicateKeyErrors(ImportDatasetDefinition definition, IReadOnlyList<ParsedImportRow> rows)
    {
        foreach (var uniqueKey in definition.UniqueKeys)
        {
            var duplicates = rows
                .Select(row => new
                {
                    Row = row,
                    Key = BuildKey(row.ParsedValues, uniqueKey.Columns),
                })
                .Where(item => item.Key is not null)
                .GroupBy(item => item.Key, StringComparer.OrdinalIgnoreCase)
                .Where(group => group.Count() > 1);

            foreach (var duplicate in duplicates)
            {
                foreach (var item in duplicate)
                {
                    AddDuplicateKeyCellErrors(item.Row, uniqueKey);
                }
            }
        }
    }

    private static void AddDuplicateKeyCellErrors(ParsedImportRow row, ImportUniqueKey uniqueKey)
    {
        foreach (var keyColumn in uniqueKey.Columns)
        {
            row.Result.CellErrors.Add(new ImportCellError(
                keyColumn,
                row.SourceHeaders.GetValueOrDefault(keyColumn),
                "duplicate_key",
                $"{uniqueKey.Name} duplicates another row in this file.",
                row.Result.Values.GetValueOrDefault(keyColumn)));
        }
    }

    private static string? BuildKey(IReadOnlyDictionary<string, object?> values, IReadOnlyList<string> columns)
    {
        var parts = new List<string>();
        foreach (var column in columns)
        {
            if (!values.TryGetValue(column, out var value) || IsMissing(value))
            {
                return null;
            }

            parts.Add(Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture) ?? "");
        }

        return string.Join('\u001f', parts);
    }

    private async Task ReplaceTargetTableAsync(
        ImportDatasetDefinition definition,
        IReadOnlyList<ParsedImportRow> rows,
        CancellationToken cancellationToken)
    {
        var connectionString = dbContext.Database.GetConnectionString();
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException("No database connection string is configured.");
        }

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(cancellationToken);

        await connection.ExecuteAsync(
            CreateTempTableSql(definition),
            transaction: transaction);

        var table = CreateDataTable(definition, rows);
        using (var bulkCopy = new SqlBulkCopy(connection, SqlBulkCopyOptions.CheckConstraints, transaction))
        {
            bulkCopy.DestinationTableName = TempTableName;
            bulkCopy.BatchSize = Math.Max(rows.Count, 1);

            bulkCopy.ColumnMappings.Add("ImportRowNumber", "ImportRowNumber");
            foreach (var column in definition.Columns)
            {
                bulkCopy.ColumnMappings.Add(column.TargetColumn, column.TargetColumn);
            }

            await bulkCopy.WriteToServerAsync(table, cancellationToken);
        }

        await RunStagingValidationAsync(connection, transaction, definition, rows, cancellationToken);

        await connection.ExecuteAsync(
            ReplaceTableSql(definition),
            transaction: transaction);

        await transaction.CommitAsync(cancellationToken);
    }

    private static async Task RunStagingValidationAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        ImportDatasetDefinition definition,
        IReadOnlyList<ParsedImportRow> rows,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        foreach (var uniqueKey in definition.UniqueKeys)
        {
            var duplicateRowNumbers = await connection.QueryAsync<int>(new CommandDefinition(
                DuplicateKeyValidationSql(uniqueKey, definition.Columns),
                transaction: transaction,
                cancellationToken: cancellationToken));

            foreach (var rowNumber in duplicateRowNumbers)
            {
                var row = rows.FirstOrDefault(candidate => candidate.RowNum == rowNumber);
                if (row is null)
                {
                    continue;
                }

                AddDuplicateKeyCellErrors(row, uniqueKey);
            }
        }

        if (rows.Any(row => row.Result.Errors.Count > 0 || row.Result.CellErrors.Count > 0))
        {
            throw new StagingValidationException();
        }
    }

    private static string DuplicateKeyValidationSql(
        ImportUniqueKey uniqueKey,
        IReadOnlyList<ImportColumn> columns)
    {
        var partitionColumns = string.Join(", ", uniqueKey.Columns.Select(Quote));
        var predicates = uniqueKey.Columns
            .Select(columnName =>
            {
                var column = columns.Single(item => item.TargetColumn == columnName);
                return column.Type == ImportColumnType.String
                    ? $"{Quote(columnName)} IS NOT NULL AND LEN(LTRIM(RTRIM({Quote(columnName)}))) > 0"
                    : $"{Quote(columnName)} IS NOT NULL";
            });

        return $"""
            SELECT [ImportRowNumber]
            FROM
            (
                SELECT
                    [ImportRowNumber],
                    COUNT(*) OVER (PARTITION BY {partitionColumns}) AS [DuplicateCount]
                FROM {TempTableName}
                WHERE {string.Join(" AND ", predicates)}
            ) AS [DuplicateRows]
            WHERE [DuplicateCount] > 1
            ORDER BY [ImportRowNumber];
            """;
    }

    private static DataTable CreateDataTable(ImportDatasetDefinition definition, IReadOnlyList<ParsedImportRow> rows)
    {
        var table = new DataTable();
        table.Columns.Add("ImportRowNumber", typeof(int));
        foreach (var column in definition.Columns)
        {
            table.Columns.Add(column.TargetColumn, GetDataTableType(column.Type));
        }

        foreach (var row in rows)
        {
            var dataRow = table.NewRow();
            dataRow["ImportRowNumber"] = row.RowNum;
            foreach (var column in definition.Columns)
            {
                var value = row.ParsedValues.GetValueOrDefault(column.TargetColumn);
                dataRow[column.TargetColumn] = ToDataTableValue(value);
            }

            table.Rows.Add(dataRow);
        }

        return table;
    }

    private static object ToDataTableValue(object? value)
    {
        return value switch
        {
            null => DBNull.Value,
            DateOnly date => date.ToDateTime(TimeOnly.MinValue),
            _ => value,
        };
    }

    private static Type GetDataTableType(ImportColumnType type)
    {
        return type switch
        {
            ImportColumnType.String => typeof(string),
            ImportColumnType.Boolean => typeof(bool),
            ImportColumnType.Decimal => typeof(decimal),
            ImportColumnType.Date => typeof(DateTime),
            ImportColumnType.Int16 => typeof(short),
            _ => typeof(string),
        };
    }

    private static string CreateTempTableSql(ImportDatasetDefinition definition)
    {
        var columnSql = definition.Columns.Select(column => $"{Quote(column.TargetColumn)} {SqlType(column)} NULL");
        return $"""
            CREATE TABLE {TempTableName}
            (
                [ImportRowNumber] INT NOT NULL,
                {string.Join(",\n                ", columnSql)}
            );
            """;
    }

    private static string ReplaceTableSql(ImportDatasetDefinition definition)
    {
        var targetTable = $"{Quote(definition.SchemaName)}.{Quote(definition.TableName)}";
        var columns = string.Join(", ", definition.Columns.Select(column => Quote(column.TargetColumn)));
        return $"""
            DELETE FROM {targetTable};

            INSERT INTO {targetTable} ({columns})
            SELECT {columns}
            FROM {TempTableName};
            """;
    }

    private static string SqlType(ImportColumn column)
    {
        return column.Type switch
        {
            ImportColumnType.String => column.MaxLength is null ? "NVARCHAR(MAX)" : $"NVARCHAR({column.MaxLength.Value})",
            ImportColumnType.Boolean => "BIT",
            ImportColumnType.Decimal => "DECIMAL(9, 2)",
            ImportColumnType.Date => "DATE",
            ImportColumnType.Int16 => "SMALLINT",
            _ => throw new ArgumentOutOfRangeException(nameof(column), column.Type, "Unsupported import column type."),
        };
    }

    private static string Quote(string identifier)
    {
        return $"[{identifier.Replace("]", "]]")}]";
    }

    private static bool IsMissing(object? value)
    {
        return value is null || value is string stringValue && string.IsNullOrWhiteSpace(stringValue);
    }

    private async Task<ImportValidationFailed> ValidationAsync(
        string dataset,
        string? filename,
        int attemptedRows,
        List<ImportFileError> fileErrors,
        List<ImportRowResult> rows,
        ClaimsPrincipal? user,
        DateTimeOffset startedAt,
        CancellationToken cancellationToken,
        string status = StatusValidationFailed)
    {
        var response = new ImportValidationResponse(dataset, filename, attemptedRows, ImportLogId: null, fileErrors, rows);
        var importLogId = await LogImportAttemptAsync(
            dataset,
            filename,
            attemptedRows,
            rowsImported: null,
            status,
            JsonSerializer.Serialize(response),
            user,
            startedAt,
            cancellationToken);

        return new ImportValidationFailed(response with { ImportLogId = importLogId });
    }

    private async Task<int> LogImportAttemptAsync(
        string dataset,
        string? filename,
        int attemptedRows,
        int? rowsImported,
        string status,
        string? errorPayload,
        ClaimsPrincipal? user,
        DateTimeOffset startedAt,
        CancellationToken cancellationToken)
    {
        var importLog = new ImportLog
        {
            Dataset = Truncate(dataset, 100),
            Filename = Truncate(Path.GetFileName(filename ?? string.Empty), 260),
            UploadedByEntraId = user?.GetEntraId(),
            UploadedByName = Truncate(user?.FindFirst("name")?.Value ?? user?.Identity?.Name, 200),
            UploadedByEmail = Truncate(user?.FindFirst("preferred_username")?.Value ?? user?.FindFirst(ClaimTypes.Email)?.Value, 320),
            StartedAt = startedAt,
            CompletedAt = DateTimeOffset.UtcNow,
            AttemptedRows = attemptedRows,
            RowsImported = rowsImported,
            Status = status,
            ErrorPayload = errorPayload,
        };

        dbContext.ImportLogs.Add(importLog);
        await dbContext.SaveChangesAsync(cancellationToken);

        return importLog.Id;
    }

    private static string Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        return value.Length <= maxLength ? value : value[..maxLength];
    }

    private sealed record HeaderBinding(string SourceHeader, ImportColumn Column);

    private sealed record ParsedCell(object? Value, ImportCellError? Error);

    private sealed record WorkbookParseResult(
        List<ImportFileError> FileErrors,
        List<ImportRowResult> Rows,
        List<ParsedImportRow> ParsedRows);

    private sealed record ParsedImportRow(
        int RowNum,
        ImportRowResult Result,
        Dictionary<string, object?> ParsedValues,
        Dictionary<string, string?> SourceHeaders);

    private sealed class StagingValidationException() : InvalidOperationException("Staging validation failed.");
}
