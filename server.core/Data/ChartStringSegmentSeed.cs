using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public static class ChartStringSegmentSeed
{
    public static IReadOnlyList<ChartStringSegment> Rows { get; } =
    [
        new() { SegmentType = SegmentType.FinancialDepartment, Code = "031000", Description = "Plant Sciences", IncludeInReport = true },
        new() { SegmentType = SegmentType.FinancialDepartment, Code = "031100", Description = "Entomology and Nematology", IncludeInReport = null },
        new() { SegmentType = SegmentType.FinancialDepartment, Code = "031200", Description = "Land, Air and Water Resources", IncludeInReport = null },
        new() { SegmentType = SegmentType.Account, Code = "500000", Description = "Supplies and Expense", IncludeInReport = null },
        new() { SegmentType = SegmentType.Fund, Code = "45530", Description = "AES State Appropriations", IncludeInReport = true, Sfn = "220" },
        new() { SegmentType = SegmentType.Fund, Code = "95981", Description = "USDA NIFA Hatch", IncludeInReport = true, Sfn = "201" },
        new() { SegmentType = SegmentType.Fund, Code = "70575", Description = "USDA NIFA SCRI Berry 2026", IncludeInReport = null, Sfn = "219" },
        new() { SegmentType = SegmentType.Activity, Code = "44A100", Description = "Research", IncludeInReport = true },
        new() { SegmentType = SegmentType.Activity, Code = "44A200", Description = "Extension", IncludeInReport = null },
    ];

    public static async Task EnsureSeededAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (await db.ChartStringSegments.AnyAsync(ct))
        {
            return;
        }

        db.ChartStringSegments.AddRange(Rows.Select(row => new ChartStringSegment
        {
            SegmentType = row.SegmentType,
            Code = row.Code,
            Description = row.Description,
            IncludeInReport = row.IncludeInReport,
            Sfn = row.Sfn,
        }));

        await db.SaveChangesAsync(ct);
    }
}
