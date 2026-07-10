using Server.Models.Imports;

namespace Server.Models.ProjectIdentification;

public sealed record ProjectIdentificationSetupResponse(
    int WorkflowRunId,
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    IReadOnlyList<FiscalPeriodOptionDto> FiscalPeriodOptions,
    int CompletedCount,
    int TotalCount,
    IReadOnlyList<ProjectChecklistItemDto> ChecklistItems);

public sealed record FiscalPeriodOptionDto(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    string Label);

public sealed record ProjectChecklistItemDto(
    string Id,
    int Number,
    string Label,
    string Hint,
    string Kind,
    string Status,
    bool Completed,
    bool Ready,
    bool Stale,
    string? StaleReason,
    RecentImportResponse? LatestImport,
    ProjectChecklistSourceDto? Source);

public sealed record ProjectChecklistSourceDto(
    int? ImportLogId,
    string? Key,
    int? Rows,
    DateTimeOffset? CompletedAt);

public sealed record FiscalPeriodRequest(string FiscalYear);

public sealed record ChecklistCompletionRequest(bool Completed);
