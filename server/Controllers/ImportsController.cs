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
            .Where(log => datasetIds.Contains(log.Dataset))
            .OrderByDescending(log => log.CompletedAt)
            .Take(datasetIds.Count * 10)
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
                        log.UploadedByEmail)
                    : null))
            .ToList();

        return Ok(summaries);
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
