namespace Server.Models.SegmentClassifications;

public sealed record SfnEntry(string Code, string Description);

/// <summary>
/// The AD419 fund SFN catalog (State Funding Number codes and their line display
/// descriptors). Code and description are always separate fields; display composes
/// them. Source: AD419 report line descriptors.
/// </summary>
public static class SfnCatalog
{
    public static readonly IReadOnlyList<SfnEntry> Entries =
    [
        new("201", "Hatch Funds"),
        new("202", "Multi-State Research Funds"),
        new("203", "McIntire-Stennis Funds"),
        new("204", "Contracts, Grants, Research Coop Agreements"),
        new("205", "OtherFunds(AnimalHealthSec1433,Evans-Allen)"),
        new("209", "National Science Foundation"),
        new("219", "USDA Contracts, Grants, Coop Agreements"),
        new("220", "State Appropriations"),
        new("221", "Self-Generated Funds"),
        new("222", "Industry Grants and Agreements"),
        new("223", "Other Non-Federal Funds"),
    ];
}
