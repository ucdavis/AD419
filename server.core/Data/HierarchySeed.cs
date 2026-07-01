using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

public static class HierarchySeed
{
    public static async Task EnsureSeededAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (!await db.DepartmentHierarchies.AnyAsync(ct))
        {
            db.DepartmentHierarchies.AddRange(
                new DepartmentHierarchy { Code = "031000", Description = "Plant Sciences",
                    ParentLevelACode = "AAES", ParentLevelAName = "Agricultural Experiment Station",
                    ParentLevelBCode = "CAES", ParentLevelBName = "College of Ag & Environmental Sciences" },
                new DepartmentHierarchy { Code = "031100", Description = "Entomology and Nematology",
                    ParentLevelACode = "AAES", ParentLevelAName = "Agricultural Experiment Station",
                    ParentLevelBCode = "CAES", ParentLevelBName = "College of Ag & Environmental Sciences" },
                new DepartmentHierarchy { Code = "031200", Description = "Land, Air and Water Resources",
                    ParentLevelACode = "AAES", ParentLevelAName = "Agricultural Experiment Station",
                    ParentLevelBCode = "CAES", ParentLevelBName = "College of Ag & Environmental Sciences" });
        }

        if (!await db.AccountHierarchies.AnyAsync(ct))
        {
            db.AccountHierarchies.Add(
                new AccountHierarchy { Code = "500000", Description = "Supplies and Expense",
                    ParentLevel0Code = "EXP", ParentLevel0Name = "Expenses",
                    ParentLevel1Code = "SUP", ParentLevel1Name = "Supplies & Expense" });
        }

        if (!await db.FundHierarchies.AnyAsync(ct))
        {
            db.FundHierarchies.AddRange(
                new FundHierarchy { Code = "45530", Description = "AES State Appropriations",
                    ParentLevel0Code = "STATE", ParentLevel0Name = "State Funds",
                    ParentLevel1Code = "APPROP", ParentLevel1Name = "Appropriations" },
                new FundHierarchy { Code = "95981", Description = "USDA NIFA Hatch",
                    ParentLevel0Code = "FED", ParentLevel0Name = "Federal Funds",
                    ParentLevel1Code = "NIFA", ParentLevel1Name = "USDA NIFA" },
                new FundHierarchy { Code = "70575", Description = "USDA NIFA SCRI Berry 2026",
                    ParentLevel0Code = "FED", ParentLevel0Name = "Federal Funds",
                    ParentLevel1Code = "NIFA", ParentLevel1Name = "USDA NIFA" });
        }

        if (!await db.ActivityHierarchies.AnyAsync(ct))
        {
            db.ActivityHierarchies.AddRange(
                new ActivityHierarchy { Code = "44A100", Description = "Research",
                    ParentLevel0Code = "MISSION", ParentLevel0Name = "Mission Activities" },
                new ActivityHierarchy { Code = "44A200", Description = "Extension",
                    ParentLevel0Code = "MISSION", ParentLevel0Name = "Mission Activities" });
        }

        await db.SaveChangesAsync(ct);
    }
}
