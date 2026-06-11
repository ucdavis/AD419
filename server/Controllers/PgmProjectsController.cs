using Microsoft.AspNetCore.Mvc;
using Server.Core.Import;

namespace Server.Controllers;

public class PgmProjectsController : ApiControllerBase
{
    private readonly IPgmProjectsImportService _importService;

    public PgmProjectsController(IPgmProjectsImportService importService)
    {
        _importService = importService;
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
        return Ok(result);
    }
}
