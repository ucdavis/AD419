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
    private const int PreClassifiedPerType = 2;

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

        db.ChartStringSegments.AddRange(segments);
        await db.SaveChangesAsync(ct);
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
            .Select((row, index) => new ChartStringSegment
            {
                SegmentType = type,
                Code = row.Code,
                Description = row.Description,
                IncludeInReport = index < PreClassifiedPerType ? true : null,
            })
            .ToList();
    }
}
