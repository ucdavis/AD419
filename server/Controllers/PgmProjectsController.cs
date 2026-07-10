using Microsoft.AspNetCore.Mvc;
using Server.Core.Import;
using Server.ProjectIdentification;

namespace Server.Controllers;

public class PgmProjectsController : ApiControllerBase
{
    private readonly IPgmProjectsImportService _importService;
    private readonly IProjectIdentificationService _projectIdentificationService;

    public PgmProjectsController(
        IPgmProjectsImportService importService,
        IProjectIdentificationService projectIdentificationService)
    {
        _importService = importService;
        _projectIdentificationService = projectIdentificationService;
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
        await _projectIdentificationService.RecordPgmImportAsync(result, User, cancellationToken);
        return Ok(result);
    }
}
