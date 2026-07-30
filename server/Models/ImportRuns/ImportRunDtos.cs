using Server.Core.Domain;

namespace Server.Models.ImportRuns;

public sealed record ImportRunStageDto(
    string Name,
    int Ordinal,
    string Status,
    int? RowCount,
    string? Detail,
    DateTimeOffset? StartedAt,
    DateTimeOffset? CompletedAt,
    string? ErrorDetail);

public sealed record ImportRunDto(
    int Id,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    string Status,
    string? TriggeredByName,
    DateTimeOffset StartedAt,
    DateTimeOffset? CompletedAt,
    IReadOnlyList<ImportRunStageDto> Stages)
{
    public static ImportRunDto From(ImportRun run) => new(
        run.Id,
        run.CycleStart,
        run.CycleEnd,
        run.Status,
        run.TriggeredByName,
        run.StartedAt,
        run.CompletedAt,
        run.Stages
            .OrderBy(stage => stage.Ordinal)
            .Select(stage => new ImportRunStageDto(
                stage.Name,
                stage.Ordinal,
                stage.Status,
                stage.RowCount,
                stage.Detail,
                stage.StartedAt,
                stage.CompletedAt,
                stage.ErrorDetail))
            .ToList());
}

public sealed record StartImportRunRequest(DateOnly? CycleStart, DateOnly? CycleEnd);
