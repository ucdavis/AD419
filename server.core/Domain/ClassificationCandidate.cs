namespace Server.Core.Domain;

/// <summary>
/// A chart-string code worth classifying: at least one transaction carrying it
/// passes every report rule except the code's own classification. Read-only,
/// mapped to [data].[v_ClassificationCandidates].
/// </summary>
public class ClassificationCandidate
{
    public SegmentType SegmentType { get; set; }

    public string Code { get; set; } = string.Empty;

    /// <summary>
    /// Key for matching candidates to SegmentClassifications rows in memory.
    /// Codes are uppercased because SQL Server compares them case-insensitively,
    /// so the view can return a casing that differs from the seeded row.
    /// </summary>
    public static (SegmentType SegmentType, string Code) Key(SegmentType segmentType, string code) =>
        (segmentType, code.ToUpperInvariant());
}
