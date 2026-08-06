using System.Globalization;

namespace Server.Core.Import;

public static class ImportSql
{
    // The 204 carve-out list shared by the AE and UCPath imports. Every 204 row
    // has an AEProjectNumber by the readiness guard; the null filter is defense
    // in depth.
    public const string Projects204Sql = """
        SELECT DISTINCT [AEProjectNumber] FROM [data].[Projects]
        WHERE [Sfn] = '204' AND [AEProjectNumber] IS NOT NULL
        """;

    // Period names must match how ClassifyTransactions generates its cycle set
    // (FORMAT(@month, 'MMM-yy', 'en-US')) so pull and stamp agree.
    public static List<string> PeriodNames(DateOnly start, DateOnly end)
    {
        var names = new List<string>();
        var month = new DateOnly(start.Year, start.Month, 1);
        while (month <= end)
        {
            names.Add(month.ToString("MMM-yy", CultureInfo.GetCultureInfo("en-US")));
            month = month.AddMonths(1);
        }

        return names;
    }

    public static string QuoteList(IEnumerable<string> values) =>
        string.Join(",", values.Select(v => $"'{v.Replace("'", "''")}'"));

    public static int HoursInFederalFiscalYear(int federalFiscalYear) =>
        federalFiscalYear % 4 == 0 ? 2096 : 2088;

    public static (DateOnly Start, DateOnly End) BufferedWindow(DateOnly cycleStart, DateOnly cycleEnd) =>
        (cycleStart.AddMonths(-3), cycleEnd.AddMonths(3));
}
