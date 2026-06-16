namespace Server.Models.Imports;

public sealed record ImportCellError(
    string TargetColumn,
    string? SourceHeader,
    string Code,
    string Message,
    string? RawValue);

public sealed record ImportFileError(
    string Code,
    string Message,
    string? SourceHeader = null,
    string? TargetColumn = null);

public sealed record ImportRowResult(
    int RowNum,
    Dictionary<string, string?> Values,
    List<string> Errors,
    List<ImportCellError> CellErrors);

public sealed record ImportValidationResponse(
    string Dataset,
    string? Filename,
    int AttemptedRows,
    int? ImportLogId,
    List<ImportFileError> FileErrors,
    List<ImportRowResult> Rows)
{
    public bool Succeeded => false;
}

public sealed record ImportSuccessResponse(
    string Dataset,
    string Filename,
    int RowsImported,
    int? ImportLogId,
    DateTimeOffset ImportedAt)
{
    public bool Succeeded => true;
}

public sealed record RecentImportResponse(
    int Id,
    string Dataset,
    string Filename,
    string Status,
    int AttemptedRows,
    int? RowsImported,
    DateTimeOffset ImportedAt,
    string? UploadedByName,
    string? UploadedByEmail,
    ImportValidationStatsResponse? ValidationStats = null);

public sealed record ImportValidationStatsResponse(
    int RowCount,
    int RowsWithErrors,
    int ErrorCount,
    int FileErrorCount);

public sealed record ImportDatasetSummaryResponse(
    string Dataset,
    string DisplayName,
    RecentImportResponse? LastImport);

public sealed record ImportLogDetailResponse(
    int Id,
    string Dataset,
    string Filename,
    string Status,
    int AttemptedRows,
    int? RowsImported,
    DateTimeOffset ImportedAt,
    string? UploadedByName,
    string? UploadedByEmail,
    ImportValidationHistoryResponse? Validation);

public sealed record ImportValidationHistoryResponse(
    string Dataset,
    string? Filename,
    int AttemptedRows,
    List<ImportFileError> FileErrors,
    int RowCount,
    int RowsWithErrors,
    int ErrorCount,
    List<ImportValidationHistoryRow> Rows,
    bool Truncated);

public sealed record ImportValidationHistoryRow(
    int RowNum,
    List<string> Errors,
    List<ImportCellError> CellErrors);
