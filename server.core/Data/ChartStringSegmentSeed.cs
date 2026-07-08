using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

/// <summary>
/// Seeds the chart-string segments that need classifying, derived from the hierarchy
/// tables so every segment has a matching breadcrumb. Runs after <see cref="HierarchySeed"/>.
/// Segments start unclassified (IncludeInReport = null); a couple per type are
/// pre-classified so the grid shows a mix of unset and classified rows.
/// </summary>
public static class ChartStringSegmentSeed
{
    // Leave roughly this many rows per segment type unclassified so there is still
    // work to do; the rest are classified (include/exclude) below.
    private const int UnsetPerType = 10;

    // Valid SFN values (mirrors the server's FundSfns / client FUND_SFNS list, plus the
    // "Multiple" marker). Used to give seeded, included funds a real SFN so the Fund
    // dropdown reflects a classified state rather than reading "Unset".
    private static readonly string[] FundSfnPool =
        ["201", "202", "203", "204", "205", "209", "219", "220", "221", "222", "223", "Multiple"];

    public static async Task EnsureSeededAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (await db.ChartStringSegments.AnyAsync(ct))
        {
            return;
        }

        var segments = new List<ChartStringSegment>();
        segments.AddRange(await BuildAsync(db.AccountHierarchies, SegmentType.Account, ct));
        segments.AddRange(await BuildAsync(db.FundHierarchies, SegmentType.Fund, ct));
        segments.AddRange(await BuildAsync(db.ActivityHierarchies, SegmentType.Activity, ct));
        segments.AddRange(await BuildAsync(db.DepartmentHierarchies, SegmentType.FinancialDepartment, ct));
        segments.AddRange(BuildErn());

        db.ChartStringSegments.AddRange(segments);
        await db.SaveChangesAsync(ct);
    }

    // ErnCodes.csv columns: 0 DOS_Code, 1 Description, 2 IncludeInAD419FTE, 3 IsNewInUCP.
    // IncludeInAD419FTE seeds the classification directly, except the first few (by DOS
    // code) which stay unset for demo. IsNewInUCP is not consumed yet.
    private static List<ChartStringSegment> BuildErn()
    {
        var rows = SeedCsv.ReadRows("ErnCodes.csv", fields => (
            Code: fields[0].Trim(),
            Description: SeedCsv.Nullable(fields[1]),
            Include: string.Equals(fields[2].Trim(), "true", StringComparison.OrdinalIgnoreCase)));

        return rows
            .OrderBy(row => row.Code, StringComparer.Ordinal)
            .Select((row, index) => new ChartStringSegment
            {
                SegmentType = SegmentType.Ern,
                Code = row.Code,
                Description = row.Description,
                IncludeInReport = index < UnsetPerType ? null : row.Include,
            })
            .ToList();
    }

    private static async Task<List<ChartStringSegment>> BuildAsync<T>(
        DbSet<T> hierarchy,
        SegmentType type,
        CancellationToken ct)
        where T : class, ISegmentHierarchy
    {
        var rows = await hierarchy.ToListAsync(ct);
        return rows
            .OrderBy(row => row.Code, StringComparer.Ordinal)
            .Select((row, index) =>
            {
                // First few stay unset; the rest are classified include/exclude with a
                // stable pseudo-random split so dev data looks partially worked.
                bool? include = index < UnsetPerType ? null : (StableHash(row.Code) & 1) == 0;

                // An included fund must carry a valid SFN, otherwise the Fund dropdown
                // has no matching option and shows "Unset" despite being classified.
                var sfn = type == SegmentType.Fund && include == true
                    ? FundSfnPool[(StableHash(row.Code) & int.MaxValue) % FundSfnPool.Length]
                    : null;

                return new ChartStringSegment
                {
                    SegmentType = type,
                    Code = row.Code,
                    Description = row.Description,
                    IncludeInReport = include,
                    Sfn = sfn,
                };
            })
            .ToList();
    }

    private static int StableHash(string value)
    {
        var hash = 17;
        foreach (var c in value)
        {
            hash = (hash * 31) + c;
        }

        return hash;
    }
}
