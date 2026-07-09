using Microsoft.AspNetCore.Mvc;
using Server.Models;
using Server.ProjectList;

namespace Server.Controllers;

public sealed class ProjectListController(IProjectListService projectListService) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string? fy, CancellationToken cancellationToken)
    {
        if (!FiscalYearCycle.TryParse(fy, out var cycle))
        {
            return BadRequest("A fiscal year query value like FY26 is required.");
        }

        var response = await projectListService.GetAsync(cycle!, cancellationToken);
        return Ok(response);
    }
}
