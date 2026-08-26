using System.Security.Claims;
using Server.Core.Domain;
using Server.Models.Workflow;

namespace Server.Workflow;

public interface IWorkflowService
{
    Task<WorkflowRun> GetOrCreateCurrentRunAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task<WorkflowSnapshotResponse> GetSnapshotAsync(
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task<WorkflowSnapshotResponse?> SetStageStatusAsync(
        string stageId,
        string status,
        ClaimsPrincipal user,
        CancellationToken cancellationToken);

    Task ResetFromStageAsync(
        string stageId,
        ClaimsPrincipal user,
        CancellationToken cancellationToken);
}
