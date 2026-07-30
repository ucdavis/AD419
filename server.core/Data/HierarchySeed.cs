using Microsoft.EntityFrameworkCore;
using Server.Core.Domain;

namespace Server.Core.Data;

/// <summary>
/// Seeds the four chart-segment hierarchy tables from embedded CSV resources
/// (server.core/Data/Seed/*.csv). The Account/Fund/Activity CSVs map directly to
/// their tables. Department has no source hierarchy of its own, so it is derived
/// from DepartmentSource.csv: levels D-G come from the FinancialDept columns and
/// levels A-C are synthesized (UC Davis > College > Experiment Station).
/// </summary>
public static class HierarchySeed
{
    public static async Task EnsureSeededAsync(DataDbContext db, CancellationToken ct = default)
    {
        if (!await db.AccountHierarchies.AnyAsync(ct))
        {
            db.AccountHierarchies.AddRange(SeedCsv.ReadRows("AccountHierarchy.csv", f => AccountFrom(WithoutSelfLevels(f))));
        }

        if (!await db.FundHierarchies.AnyAsync(ct))
        {
            db.FundHierarchies.AddRange(SeedCsv.ReadRows("FundHierarchy.csv", f => FundFrom(WithoutSelfLevels(f))));
        }

        if (!await db.ActivityHierarchies.AnyAsync(ct))
        {
            db.ActivityHierarchies.AddRange(SeedCsv.ReadRows("ActivityHierarchy.csv", f => ActivityFrom(WithoutSelfLevels(f))));
        }

        if (!await db.PurposeHierarchies.AnyAsync(ct))
        {
            db.PurposeHierarchies.AddRange(SeedCsv.ReadRows("PurposeHierarchy.csv", f => PurposeFrom(WithoutSelfLevels(f))));
        }

        if (!await db.DepartmentHierarchies.AnyAsync(ct))
        {
            db.DepartmentHierarchies.AddRange(DepartmentRows());
        }

        await db.SaveChangesAsync(ct);
    }

    // A level cell that repeats the row's own code is a storage artifact of the
    // warehouse's fixed-width hierarchy format and carries no information.
    // Blank it (code and name) at load so stored rows are clean for every consumer.
    private static string[] WithoutSelfLevels(string[] f)
    {
        for (var i = 2; i <= 12; i += 2)
        {
            if (i < f.Length && f[i].Trim() == f[0].Trim())
            {
                f[i] = string.Empty;
                if (i + 1 < f.Length) { f[i + 1] = string.Empty; }
            }
        }

        return f;
    }

    private static AccountHierarchy AccountFrom(string[] f) => new()
    {
        Code = f[0],
        Description = SeedCsv.Nullable(f[1]),
        ParentLevel0Code = SeedCsv.Nullable(f[2]), ParentLevel0Name = SeedCsv.Nullable(f[3]),
        ParentLevel1Code = SeedCsv.Nullable(f[4]), ParentLevel1Name = SeedCsv.Nullable(f[5]),
        ParentLevel2Code = SeedCsv.Nullable(f[6]), ParentLevel2Name = SeedCsv.Nullable(f[7]),
        ParentLevel3Code = SeedCsv.Nullable(f[8]), ParentLevel3Name = SeedCsv.Nullable(f[9]),
        ParentLevel4Code = SeedCsv.Nullable(f[10]), ParentLevel4Name = SeedCsv.Nullable(f[11]),
        ParentLevel5Code = SeedCsv.Nullable(f[12]), ParentLevel5Name = SeedCsv.Nullable(f[13]),
    };

    private static FundHierarchy FundFrom(string[] f) => new()
    {
        Code = f[0],
        Description = SeedCsv.Nullable(f[1]),
        ParentLevel0Code = SeedCsv.Nullable(f[2]), ParentLevel0Name = SeedCsv.Nullable(f[3]),
        ParentLevel1Code = SeedCsv.Nullable(f[4]), ParentLevel1Name = SeedCsv.Nullable(f[5]),
        ParentLevel2Code = SeedCsv.Nullable(f[6]), ParentLevel2Name = SeedCsv.Nullable(f[7]),
        ParentLevel3Code = SeedCsv.Nullable(f[8]), ParentLevel3Name = SeedCsv.Nullable(f[9]),
        ParentLevel4Code = SeedCsv.Nullable(f[10]), ParentLevel4Name = SeedCsv.Nullable(f[11]),
        ParentLevel5Code = SeedCsv.Nullable(f[12]), ParentLevel5Name = SeedCsv.Nullable(f[13]),
    };

    private static ActivityHierarchy ActivityFrom(string[] f) => new()
    {
        Code = f[0],
        Description = SeedCsv.Nullable(f[1]),
        ParentLevel0Code = SeedCsv.Nullable(f[2]), ParentLevel0Name = SeedCsv.Nullable(f[3]),
        ParentLevel1Code = SeedCsv.Nullable(f[4]), ParentLevel1Name = SeedCsv.Nullable(f[5]),
        ParentLevel2Code = SeedCsv.Nullable(f[6]), ParentLevel2Name = SeedCsv.Nullable(f[7]),
        ParentLevel3Code = SeedCsv.Nullable(f[8]), ParentLevel3Name = SeedCsv.Nullable(f[9]),
        ParentLevel4Code = SeedCsv.Nullable(f[10]), ParentLevel4Name = SeedCsv.Nullable(f[11]),
        ParentLevel5Code = SeedCsv.Nullable(f[12]), ParentLevel5Name = SeedCsv.Nullable(f[13]),
    };

    private static PurposeHierarchy PurposeFrom(string[] f) => new()
    {
        Code = f[0],
        Description = SeedCsv.Nullable(f[1]),
        ParentLevel0Code = SeedCsv.Nullable(f[2]), ParentLevel0Name = SeedCsv.Nullable(f[3]),
        ParentLevel1Code = SeedCsv.Nullable(f[4]), ParentLevel1Name = SeedCsv.Nullable(f[5]),
        ParentLevel2Code = SeedCsv.Nullable(f[6]), ParentLevel2Name = SeedCsv.Nullable(f[7]),
        ParentLevel3Code = SeedCsv.Nullable(f[8]), ParentLevel3Name = SeedCsv.Nullable(f[9]),
        ParentLevel4Code = SeedCsv.Nullable(f[10]), ParentLevel4Name = SeedCsv.Nullable(f[11]),
        ParentLevel5Code = SeedCsv.Nullable(f[12]), ParentLevel5Name = SeedCsv.Nullable(f[13]),
    };

    // DepartmentSource.csv columns:
    // 0 D code, 1 D name, 2 E code, 3 E name, 4 F code, 5 F name, 6 G code, 7 G name, ... (fact columns ignored)
    private static List<DepartmentHierarchy> DepartmentRows() =>
        SeedCsv.ReadRows("DepartmentSource.csv", f => f)
            .GroupBy(f => f[6])
            .Select(rows => rows.First())
            .Select(f => new DepartmentHierarchy
            {
                Code = f[6],
                Description = SeedCsv.Nullable(f[7]),
                ParentLevelACode = "UCD", ParentLevelAName = "UC Davis",
                ParentLevelBCode = "CAES", ParentLevelBName = "College of Agricultural and Environmental Sciences",
                ParentLevelCCode = "AAES", ParentLevelCName = "Agricultural Experiment Station",
                ParentLevelDCode = SeedCsv.Nullable(f[0]), ParentLevelDName = SeedCsv.Nullable(f[1]),
                ParentLevelECode = SeedCsv.Nullable(f[2]), ParentLevelEName = SeedCsv.Nullable(f[3]),
                ParentLevelFCode = SeedCsv.Nullable(f[4]), ParentLevelFName = SeedCsv.Nullable(f[5]),
            })
            .ToList();
}
