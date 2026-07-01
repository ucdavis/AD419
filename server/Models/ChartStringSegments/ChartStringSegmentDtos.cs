namespace Server.Models.ChartStringSegments;

public sealed record ChartStringSegmentDto(
    string SegmentType,
    string Code,
    string? Description,
    bool? IncludeInReport,
    string? Sfn,
    IReadOnlyList<HierarchyLevelDto> Hierarchy);

public sealed record HierarchyLevelDto(string Level, string Code, string? Name);

public sealed record UpdateClassificationRequest(
    string SegmentType,
    string Code,
    bool? IncludeInReport,
    string? Sfn);
