using System.Globalization;

namespace Server.Models;

public sealed record FiscalYearCycle(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd)
{
    public static bool TryParse(string? fiscalYear, out FiscalYearCycle? cycle)
    {
        cycle = null;

        if (string.IsNullOrWhiteSpace(fiscalYear))
        {
            return false;
        }

        var normalized = fiscalYear.Trim().ToUpperInvariant();
        if (!normalized.StartsWith("FY", StringComparison.Ordinal) ||
            normalized.Length < 4 ||
            !int.TryParse(normalized[2..], NumberStyles.None, CultureInfo.InvariantCulture, out var shortYear))
        {
            return false;
        }

        var endYear = shortYear < 100 ? 2000 + shortYear : shortYear;
        var startYear = endYear - 1;
        cycle = new FiscalYearCycle(
            $"FY{endYear % 100:00}",
            new DateOnly(startYear, 10, 1),
            new DateOnly(endYear, 9, 30));
        return true;
    }
}
