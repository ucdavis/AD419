namespace Server.Models.ChartStringSegments;

public static class FundSfns
{
    public const string MultipleMarker = "Multiple";

    public static readonly IReadOnlySet<string> Codes =
        new HashSet<string> { "201", "202", "203", "205", "220", "221", "223" };

    public static bool IsValidForInclusion(string? sfn) =>
        sfn is not null && (Codes.Contains(sfn) || sfn == MultipleMarker);
}
