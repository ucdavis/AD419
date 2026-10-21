using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

/// <summary>
/// Seeds development classifications for ERN codes and the purposes the 2025
/// processing rules decided. Every other code, and any purpose those rules leave
/// open, is added unclassified by the import's SeedSegmentClassifications stage.
/// </summary>
public static class SegmentClassificationSeed
{
    // Leave this many ERN codes unclassified so there is still work to do.
    private const int UnsetPerType = 10;

    public static async Task EnsureSeededAsync(DataDbContext db, CancellationToken ct = default)
    {
        if (await db.SegmentClassifications.AnyAsync(ct))
        {
            return;
        }

        var segments = new List<SegmentClassification>();
        segments.AddRange(BuildErn());
        segments.AddRange(await BuildPurposeAsync(db, ct));

        db.SegmentClassifications.AddRange(segments);
        await db.SaveChangesAsync(ct);
    }

    // ErnCodes.csv columns: 0 ErnCode, 1 Description, 2 IncludeInAD419FTE, 3 IsNewInUCP.
    // IncludeInAD419FTE seeds the classification directly, except the first few (by ERN
    // code) which stay unset for demo. IsNewInUCP is not consumed yet.
    private static List<SegmentClassification> BuildErn()
    {
        var rows = SeedCsv.ReadRows("ErnCodes.csv", fields => (
            Code: fields[0].Trim(),
            Description: SeedCsv.Nullable(fields[1]),
            Include: string.Equals(fields[2].Trim(), "true", StringComparison.OrdinalIgnoreCase)));

        return rows
            .OrderBy(row => row.Code, StringComparer.Ordinal)
            .Select((row, index) => new SegmentClassification
            {
                SegmentType = SegmentType.Ern,
                Code = row.Code,
                Description = row.Description,
                IncludeInReport = index < UnsetPerType ? null : row.Include,
            })
            .ToList();
    }

    // Purpose classification defaults follow the 2025 processing rules: the known
    // exclusion list is excluded and research purposes are included. Codes the 2025
    // process never ruled on are left to the import, which adds them unset so they
    // surface for review (fail closed).
    private static readonly IReadOnlySet<string> ExcludedPurposes =
        new HashSet<string> { "00", "40", "43", "60", "61", "62", "72", "76", "78", "80" };

    private static readonly IReadOnlySet<string> IncludedPurposes =
        new HashSet<string> { "44", "45" };

    private static async Task<List<SegmentClassification>> BuildPurposeAsync(DataDbContext db, CancellationToken ct)
    {
        var descriptions = await db.ChartSegments
            .Where(segment => segment.SegmentName == nameof(SegmentType.Purpose))
            .ToDictionaryAsync(segment => segment.Code, segment => segment.Description, ct);

        return ExcludedPurposes.Select(code => (Code: code, Include: false))
            .Concat(IncludedPurposes.Select(code => (Code: code, Include: true)))
            .OrderBy(purpose => purpose.Code, StringComparer.Ordinal)
            .Select(purpose => new SegmentClassification
            {
                SegmentType = SegmentType.Purpose,
                Code = purpose.Code,
                Description = descriptions.GetValueOrDefault(purpose.Code),
                IncludeInReport = purpose.Include,
            })
            .ToList();
    }
}
