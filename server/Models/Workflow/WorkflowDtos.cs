using Server.Core.Domain;

namespace Server.Models.Workflow;

public sealed record WorkflowSnapshotResponse(
    int WorkflowRunId,
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    string CurrentStageId,
    IReadOnlyList<WorkflowStageDto> Stages);

public sealed record WorkflowStageDto(
    string Id,
    int Number,
    string Title,
    string Description,
    string Status,
    bool CanAccess,
    DateTimeOffset? CompletedAt,
    string? CompletedByName,
    string? CompletedByEmail);

public sealed record UpdateWorkflowStageRequest(string? Status)
{
    public bool IsValidStatus() =>
        Status is WorkflowStageStatus.InProgress or WorkflowStageStatus.Complete;
}
