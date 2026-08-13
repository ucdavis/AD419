using Microsoft.AspNetCore.Mvc;
using Server.Models.Workflow;
using Server.Workflow;

namespace Server.Controllers;

public sealed class WorkflowController(IWorkflowService workflowService) : ApiControllerBase
{
    [HttpGet("snapshot")]
    public async Task<ActionResult<WorkflowSnapshotResponse>> Snapshot(
        CancellationToken cancellationToken)
    {
        var response = await workflowService.GetSnapshotAsync(User, cancellationToken);
        return Ok(response);
    }

    [HttpPut("stages/{stageId}")]
    public async Task<ActionResult<WorkflowSnapshotResponse>> SetStageStatus(
        [FromRoute] string stageId,
        UpdateWorkflowStageRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Status is null || !request.IsValidStatus())
        {
            return BadRequest("Status must be InProgress or Complete.");
        }

        var response = await workflowService.SetStageStatusAsync(
            stageId,
            request.Status,
            User,
            cancellationToken);

        if (response is null)
        {
            return BadRequest("The workflow stage cannot be updated in its current state.");
        }

        return Ok(response);
    }
}
