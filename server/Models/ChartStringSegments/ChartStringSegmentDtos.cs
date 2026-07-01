namespace Server.Models.ChartStringSegments;

public sealed record ChartStringSegmentDto(
    string SegmentType,
    string Code,
    string? Description,
    bool? IncludeInReport,
    string? Sfn);

public sealed record UpdateClassificationRequest(
    string SegmentType,
    string Code,
    bool? IncludeInReport,
    string? Sfn);
