using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Import;
using Server.Models.Imports;

namespace Server.Controllers;

public sealed class ImportsController(
    IFlatFileImportService importService,
    IFlatFileImportRegistry registry,
    AppDbContext dbContext) : ApiControllerBase
{
    [HttpGet("recent")]
    public async Task<ActionResult<IReadOnlyList<ImportDatasetSummaryResponse>>> Recent(CancellationToken cancellationToken)
    {
        var datasetIds = registry.Datasets.Select(dataset => dataset.Id).ToList();
        var recentLogs = await dbContext.ImportLogs
            .AsNoTracking()
            .Where(log => datasetIds.Contains(log.Dataset))
            .Where(log => log.Id == dbContext.ImportLogs
                .Where(candidate => candidate.Dataset == log.Dataset)
                .OrderByDescending(candidate => candidate.CompletedAt)
                .ThenByDescending(candidate => candidate.Id)
                .Select(candidate => candidate.Id)
                .First())
            .OrderByDescending(log => log.CompletedAt)
            .ThenByDescending(log => log.Id)
            .Select(log => new RecentImportLog(
                log.Id,
                log.Dataset,
                log.Filename,
                log.Status,
                log.AttemptedRows,
                log.RowsImported,
                log.CompletedAt,
                log.UploadedByName,
                log.UploadedByEmail,
                log.ErrorPayload))
            .ToListAsync(cancellationToken);

        var latestByDataset = recentLogs
            .GroupBy(log => log.Dataset, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);

        var summaries = registry.Datasets
            .Select(dataset => new ImportDatasetSummaryResponse(
                dataset.Id,
                dataset.DisplayName,
                latestByDataset.TryGetValue(dataset.Id, out var log)
                    ? new RecentImportResponse(
                        log.Id,
                        log.Dataset,
                        log.Filename,
                        log.Status,
                        log.AttemptedRows,
                        log.RowsImported,
                        log.CompletedAt,
                        log.UploadedByName,
                        log.UploadedByEmail,
                        DeserializeValidationStats(log.ErrorPayload))
                    : null))
            .ToList();

        return Ok(summaries);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ImportLogDetailResponse>> Detail(
        [FromRoute] int id,
        CancellationToken cancellationToken)
    {
        var log = await dbContext.ImportLogs
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);

        if (log is null)
        {
            return NotFound();
        }

        return Ok(new ImportLogDetailResponse(
            log.Id,
            log.Dataset,
            log.Filename,
            log.Status,
            log.AttemptedRows,
            log.RowsImported,
            log.CompletedAt,
            log.UploadedByName,
            log.UploadedByEmail,
            DeserializeValidationHistory(log.ErrorPayload)));
    }

    private static ImportValidationHistoryResponse? DeserializeValidationHistory(string? errorPayload)
    {
        if (string.IsNullOrWhiteSpace(errorPayload))
        {
            return null;
        }

        try
        {
            var payload = JsonSerializer.Deserialize<ImportValidationHistoryReadModel>(errorPayload);
            if (payload is null)
            {
                return null;
            }

            var rows = payload.Rows.Count > 0 ? payload.Rows : payload.SampleRows;
            return new ImportValidationHistoryResponse(
                payload.Dataset,
                payload.Filename,
                payload.AttemptedRows,
                payload.FileErrors,
                payload.RowCount,
                payload.RowsWithErrors,
                payload.ErrorCount,
                rows,
                payload.Truncated);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static ImportValidationStatsResponse? DeserializeValidationStats(string? errorPayload)
    {
        var validation = DeserializeValidationHistory(errorPayload);
        if (validation is null)
        {
            return null;
        }

        return new ImportValidationStatsResponse(
            validation.RowCount,
            validation.RowsWithErrors,
            validation.ErrorCount,
            validation.FileErrors.Count);
    }

    private sealed record RecentImportLog(
        int Id,
        string Dataset,
        string Filename,
        string Status,
        int AttemptedRows,
        int? RowsImported,
        DateTimeOffset CompletedAt,
        string? UploadedByName,
        string? UploadedByEmail,
        string? ErrorPayload);

    private sealed class ImportValidationHistoryReadModel
    {
        public string Dataset { get; set; } = string.Empty;
        public string? Filename { get; set; }
        public int AttemptedRows { get; set; }
        public List<ImportFileError> FileErrors { get; set; } = [];
        public int RowCount { get; set; }
        public int RowsWithErrors { get; set; }
        public int ErrorCount { get; set; }
        public List<ImportValidationHistoryRow> Rows { get; set; } = [];
        public List<ImportValidationHistoryRow> SampleRows { get; set; } = [];
        public bool Truncated { get; set; }
    }

    [HttpPost("{dataset}")]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<IActionResult> Upload(
        [FromRoute] string dataset,
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        var result = await importService.ImportAsync(dataset, file, User, cancellationToken);

        return result switch
        {
            ImportSucceeded success => Ok(success.Response),
            ImportValidationFailed validation => BadRequest(validation.Response),
            _ => throw new InvalidOperationException("Unknown import result."),
        };
    }
}
