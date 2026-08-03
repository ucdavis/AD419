using Microsoft.AspNetCore.Mvc;
using Server.Models;
using Server.Models.ProjectList;
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

        var response = await projectListService.GetAsync(cycle, cancellationToken);
        return Ok(response);
    }

    [HttpGet("resolution-edits")]
    public async Task<ActionResult<ProjectResolutionEditsResponse>> ResolutionEdits(
        CancellationToken cancellationToken)
    {
        var hasResolutionEdits = await projectListService.HasResolutionEditsAsync(cancellationToken);
        return Ok(new ProjectResolutionEditsResponse(hasResolutionEdits));
    }

    [HttpGet("{accession}/all-project-candidates")]
    public async Task<ActionResult<IReadOnlyList<AllProjectCandidateDto>>> AllProjectCandidates(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        [FromQuery] string? search,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        var response = await projectListService.GetAllProjectCandidatesAsync(cycle, accession, search, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{accession}/pgm-award-candidates")]
    public async Task<ActionResult<IReadOnlyList<PgmAwardCandidateDto>>> PgmAwardCandidates(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        [FromQuery] string? search,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        var response = await projectListService.GetPgmAwardCandidatesAsync(cycle, accession, search, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{accession}/sfn-candidates")]
    public async Task<ActionResult<IReadOnlyList<SfnCandidateDto>>> SfnCandidates(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        var response = await projectListService.GetSfnCandidatesAsync(cycle, accession, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{accession}/exclude")]
    public async Task<IActionResult> Exclude(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        var result = await projectListService.ExcludeAsync(cycle, accession, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    [HttpPost("{accession}/link-all-project")]
    public async Task<IActionResult> LinkAllProject(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        LinkAllProjectRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        if (request.AllProjectId is not { } allProjectId)
        {
            return BadRequest("allProjectId is required.");
        }

        var result = await projectListService.LinkAllProjectAsync(cycle, accession, allProjectId, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    [HttpPost("{accession}/link-pgm-award")]
    public async Task<IActionResult> LinkPgmAward(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        LinkPgmAwardRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        if (string.IsNullOrWhiteSpace(request.AwardKey))
        {
            return BadRequest("awardKey is required.");
        }

        var result = await projectListService.LinkPgmAwardAsync(cycle, accession, request.AwardKey, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    [HttpPost("{accession}/set-sfn")]
    public async Task<IActionResult> SetSfn(
        [FromRoute] string accession,
        [FromQuery] string? fy,
        SetSfnRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
        }

        if (string.IsNullOrWhiteSpace(request.Sfn))
        {
            return BadRequest("sfn is required.");
        }

        var result = await projectListService.SetSfnAsync(cycle, accession, request.Sfn, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    private static bool TryParseCycle(
        string? fiscalYear,
        out FiscalYearCycle cycle,
        out string? error)
    {
        if (FiscalYearCycle.TryParse(fiscalYear, out var parsedCycle))
        {
            cycle = parsedCycle;
            error = null;
            return true;
        }

        cycle = null!;
        error = "A fiscal year query value like FY26 is required.";
        return false;
    }

    private IActionResult MapProjectListUpdateResult(ProjectListUpdateResult result)
    {
        return result.Status switch
        {
            ProjectListUpdateStatus.Updated => NoContent(),
            ProjectListUpdateStatus.NotFound => NotFound(result.Message),
            ProjectListUpdateStatus.Conflict => Conflict(result.Message),
            ProjectListUpdateStatus.InvalidRequest => BadRequest(result.Message),
            _ => BadRequest(result.Message),
        };
    }
}
