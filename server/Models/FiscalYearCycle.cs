using System.Diagnostics.CodeAnalysis;
using System.Globalization;

namespace Server.Models;

public sealed record FiscalYearCycle(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd)
{
    public static FiscalYearCycle Current() => Current(DateTimeOffset.Now);

    public static FiscalYearCycle Current(DateTimeOffset now)
    {
        var calendarYear = now.Year;
        var fiscalYear = now.Month >= 10 ? calendarYear + 1 : calendarYear;
        var fiscalYearText = $"FY{fiscalYear % 100:00}";
        if (!TryParse(fiscalYearText, out var cycle))
        {
            throw new InvalidOperationException($"Current fiscal year '{fiscalYearText}' could not be parsed.");
        }

        return cycle;
    }

    public static bool TryParse(string? fiscalYear, [NotNullWhen(true)] out FiscalYearCycle? cycle)
    {
        cycle = null;

        if (string.IsNullOrWhiteSpace(fiscalYear))
        {
            return false;
        }

        var normalized = fiscalYear.Trim().ToUpperInvariant();
        var yearText = normalized.StartsWith("FY", StringComparison.Ordinal)
            ? normalized[2..]
            : string.Empty;

        if (yearText.Length is not (2 or 4) ||
            !int.TryParse(yearText, NumberStyles.None, CultureInfo.InvariantCulture, out var parsedYear))
        {
            return false;
        }

        var endYear = yearText.Length == 2 ? 2000 + parsedYear : parsedYear;
        if (endYear is < 2 or > 9999)
        {
            return false;
        }

        var startYear = endYear - 1;
        cycle = new FiscalYearCycle(
            $"FY{endYear % 100:00}",
            new DateOnly(startYear, 10, 1),
            new DateOnly(endYear, 9, 30));
        return true;
    }
}
