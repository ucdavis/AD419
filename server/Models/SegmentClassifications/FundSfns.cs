namespace Server.Models.SegmentClassifications;

public static class FundSfns
{
    public const string MultipleMarker = "Multiple";

    public static readonly IReadOnlySet<string> Codes =
        SfnCatalog.Entries.Select(e => e.Code).ToHashSet();

    public static bool IsValidForInclusion(string? sfn) =>
        sfn is not null && (Codes.Contains(sfn) || sfn == MultipleMarker);
}
