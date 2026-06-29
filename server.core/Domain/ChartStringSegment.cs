namespace Server.Core.Domain;

public enum SegmentType
{
    FinancialDepartment,
    Account,
    Fund,
    Activity,
}

public class ChartStringSegment
{
    public SegmentType SegmentType { get; set; }

    public string Code { get; set; } = string.Empty;

    public string? Description { get; set; }

    public bool? IncludeInReport { get; set; }

    public string? Sfn { get; set; }
}
