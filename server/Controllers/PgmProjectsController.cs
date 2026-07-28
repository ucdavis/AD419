using Microsoft.AspNetCore.Mvc;
using Server.Core.Import;
using Server.ProjectIdentification;

namespace Server.Controllers;

public class PgmProjectsController : ApiControllerBase
{
    private readonly IPgmProjectsImportService _importService;
    private readonly IProjectIdentificationService _projectIdentificationService;
    private readonly ILogger<PgmProjectsController> _logger;

    public PgmProjectsController(
        IPgmProjectsImportService importService,
        IProjectIdentificationService projectIdentificationService,
        ILogger<PgmProjectsController> logger)
    {
        _importService = importService;
        _projectIdentificationService = projectIdentificationService;
        _logger = logger;
    }

    // POST api/pgmprojects/import?reportDate=2026-06-30
    // Replaces [data].[PGMProjects] with warehouse data as of the given report date.
    [HttpPost("import")]
    public async Task<ActionResult<PgmProjectsImportResult>> Import(
        [FromQuery] DateOnly? reportDate,
        CancellationToken cancellationToken)
    {
        if (reportDate is not { } date)
        {
            return BadRequest("reportDate is required (yyyy-MM-dd).");
        }

        var result = await _importService.ImportAsync(date, cancellationToken);
        try
        {
            await _projectIdentificationService.RecordPgmImportAsync(result, User, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "PGM projects import succeeded for report date {ReportDate}, but workflow recording failed.",
                date);
        }

        return Ok(result);
    }
}
