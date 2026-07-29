using Microsoft.AspNetCore.Mvc;
using Server.Models.ProjectIdentification;
using Server.ProjectIdentification;

namespace Server.Controllers;

public sealed class ProjectIdentificationController(
    IProjectIdentificationService projectIdentificationService) : ApiControllerBase
{
    [HttpGet("setup")]
    public async Task<ActionResult<ProjectIdentificationSetupResponse>> Setup(
        CancellationToken cancellationToken)
    {
        var response = await projectIdentificationService.GetSetupAsync(User, cancellationToken);
        return Ok(response);
    }

    [HttpPut("fiscal-period")]
    public async Task<ActionResult<ProjectIdentificationSetupResponse>> ConfirmFiscalPeriod(
        FiscalPeriodRequest request,
        CancellationToken cancellationToken)
    {
        var response = await projectIdentificationService.ConfirmFiscalPeriodAsync(
            request.FiscalYear,
            User,
            cancellationToken);

        if (response is null)
        {
            return BadRequest("A fiscal year value like FY26 is required.");
        }

        return Ok(response);
    }

    [HttpPut("checklist/{itemId}")]
    public async Task<ActionResult<ProjectIdentificationSetupResponse>> SetChecklistItemCompletion(
        [FromRoute] string itemId,
        ChecklistCompletionRequest request,
        CancellationToken cancellationToken)
    {
        var response = await projectIdentificationService.SetChecklistItemCompletionAsync(
            itemId,
            request.Completed,
            User,
            cancellationToken);

        if (response is null)
        {
            return BadRequest("The checklist item cannot be updated in its current state.");
        }

        return Ok(response);
    }
}
