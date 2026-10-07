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
}
