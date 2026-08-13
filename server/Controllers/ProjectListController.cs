using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.ProjectList;
using Server.ProjectList;

namespace Server.Controllers;

public sealed class ProjectListController(
    IProjectListService projectListService,
    AppDbContext appDb) : ApiControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] string? fy, CancellationToken cancellationToken)
    {
        if (!TryParseCycle(fy, out var cycle, out var error))
        {
            return BadRequest(error);
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

    // Resolution writes source the cycle from the confirmed fiscal period,
    // never from the client: a stale browser tab must not be able to apply
    // edits against the wrong year. Reads keep the client fy because they only
    // window what is displayed.
    [HttpPost("{accession}/exclude")]
    public async Task<IActionResult> Exclude(
        [FromRoute] string accession,
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] ProjectExclusionRequest? request,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var result = await projectListService.ExcludeAsync(cycle, accession, request?.Notes, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    [HttpPost("{accession}/include")]
    public async Task<IActionResult> Include(
        [FromRoute] string accession,
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] ProjectExclusionRequest? request,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        var result = await projectListService.IncludeAsync(cycle, accession, request?.Notes, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    [HttpPost("{accession}/link-all-project")]
    public async Task<IActionResult> LinkAllProject(
        [FromRoute] string accession,
        LinkAllProjectRequest request,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
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
        LinkPgmAwardRequest request,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
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
        SetSfnRequest request,
        CancellationToken cancellationToken)
    {
        var (cycle, cycleError) = await GetConfirmedCycleAsync(cancellationToken);
        if (cycle is null)
        {
            return cycleError!;
        }

        if (string.IsNullOrWhiteSpace(request.Sfn))
        {
            return BadRequest("sfn is required.");
        }

        var result = await projectListService.SetSfnAsync(cycle, accession, request.Sfn, cancellationToken);
        return MapProjectListUpdateResult(result);
    }

    private async Task<(FiscalYearCycle? Cycle, IActionResult? Error)> GetConfirmedCycleAsync(
        CancellationToken cancellationToken)
    {
        var run = await appDb.WorkflowRuns.SingleOrDefaultAsync(r => r.IsCurrent, cancellationToken);
        if (run is null || !FiscalYearCycle.TryParse(run.FiscalYear, out var cycle))
        {
            return (null, Conflict("No fiscal period has been confirmed in Project Identification."));
        }

        return (cycle, null);
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
