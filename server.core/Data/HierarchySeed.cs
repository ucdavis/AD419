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
    public static async Task EnsureSeededAsync(AppDbContext db, CancellationToken ct = default)
    {
        if (!await db.AccountHierarchies.AnyAsync(ct))
        {
            db.AccountHierarchies.AddRange(ReadRows("AccountHierarchy.csv", AccountFrom));
        }

        if (!await db.FundHierarchies.AnyAsync(ct))
        {
            db.FundHierarchies.AddRange(ReadRows("FundHierarchy.csv", FundFrom));
        }

        if (!await db.ActivityHierarchies.AnyAsync(ct))
        {
            db.ActivityHierarchies.AddRange(ReadRows("ActivityHierarchy.csv", ActivityFrom));
        }

        if (!await db.DepartmentHierarchies.AnyAsync(ct))
        {
            db.DepartmentHierarchies.AddRange(DepartmentRows());
        }

        await db.SaveChangesAsync(ct);
    }

    private static AccountHierarchy AccountFrom(string[] f) => new()
    {
        Code = f[0],
        Description = N(f[1]),
        ParentLevel0Code = N(f[2]), ParentLevel0Name = N(f[3]),
        ParentLevel1Code = N(f[4]), ParentLevel1Name = N(f[5]),
        ParentLevel2Code = N(f[6]), ParentLevel2Name = N(f[7]),
        ParentLevel3Code = N(f[8]), ParentLevel3Name = N(f[9]),
        ParentLevel4Code = N(f[10]), ParentLevel4Name = N(f[11]),
        ParentLevel5Code = N(f[12]), ParentLevel5Name = N(f[13]),
    };

    private static FundHierarchy FundFrom(string[] f) => new()
    {
        Code = f[0],
        Description = N(f[1]),
        ParentLevel0Code = N(f[2]), ParentLevel0Name = N(f[3]),
        ParentLevel1Code = N(f[4]), ParentLevel1Name = N(f[5]),
        ParentLevel2Code = N(f[6]), ParentLevel2Name = N(f[7]),
        ParentLevel3Code = N(f[8]), ParentLevel3Name = N(f[9]),
        ParentLevel4Code = N(f[10]), ParentLevel4Name = N(f[11]),
        ParentLevel5Code = N(f[12]), ParentLevel5Name = N(f[13]),
    };

    private static ActivityHierarchy ActivityFrom(string[] f) => new()
    {
        Code = f[0],
        Description = N(f[1]),
        ParentLevel0Code = N(f[2]), ParentLevel0Name = N(f[3]),
        ParentLevel1Code = N(f[4]), ParentLevel1Name = N(f[5]),
        ParentLevel2Code = N(f[6]), ParentLevel2Name = N(f[7]),
        ParentLevel3Code = N(f[8]), ParentLevel3Name = N(f[9]),
        ParentLevel4Code = N(f[10]), ParentLevel4Name = N(f[11]),
        ParentLevel5Code = N(f[12]), ParentLevel5Name = N(f[13]),
    };

    // DepartmentSource.csv columns:
    // 0 D code, 1 D name, 2 E code, 3 E name, 4 F code, 5 F name, 6 G code, 7 G name, ... (fact columns ignored)
    private static List<DepartmentHierarchy> DepartmentRows() =>
        ReadRows("DepartmentSource.csv", f => f)
            .GroupBy(f => f[6])
            .Select(rows => rows.First())
            .Select(f => new DepartmentHierarchy
            {
                Code = f[6],
                Description = N(f[7]),
                ParentLevelACode = "UCD", ParentLevelAName = "UC Davis",
                ParentLevelBCode = "CAES", ParentLevelBName = "College of Agricultural and Environmental Sciences",
                ParentLevelCCode = "AAES", ParentLevelCName = "Agricultural Experiment Station",
                ParentLevelDCode = N(f[0]), ParentLevelDName = N(f[1]),
                ParentLevelECode = N(f[2]), ParentLevelEName = N(f[3]),
                ParentLevelFCode = N(f[4]), ParentLevelFName = N(f[5]),
                ParentLevelGCode = N(f[6]), ParentLevelGName = N(f[7]),
            })
            .ToList();

    private static List<T> ReadRows<T>(string fileName, Func<string[], T> map)
    {
        using var stream = OpenResource(fileName);
        using var reader = new StreamReader(stream);
        var rows = new List<T>();
        var isHeader = true;
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            if (isHeader) { isHeader = false; continue; }
            if (string.IsNullOrWhiteSpace(line)) { continue; }
            rows.Add(map(line.Split(',')));
        }

        return rows;
    }

    private static Stream OpenResource(string fileName)
    {
        var assembly = typeof(HierarchySeed).Assembly;
        var name = assembly.GetManifestResourceNames()
            .Single(candidate => candidate.EndsWith(fileName, StringComparison.Ordinal));
        return assembly.GetManifestResourceStream(name)
            ?? throw new InvalidOperationException($"Embedded seed resource '{fileName}' was not found.");
    }

    private static string? N(string value)
    {
        var trimmed = value.Trim();
        return trimmed.Length == 0 ? null : trimmed;
    }
}
