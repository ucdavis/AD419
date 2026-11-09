namespace Server.ExpenseReview;

// Reason masks are internal to the in-memory dropdown index.
public static class ExpenseReviewExclusionReasons
{
    // AggregatePrefix requests transaction-level count/amount aggregation. When null, the predicate
    // must be constant within each transaction group and evaluable against the grouped columns.
    internal sealed record Reason(int Bit, string Code, string Label, string Predicate, string? AggregatePrefix)
    {
        public string SqlPredicate(string alias) => Predicate.Replace("{alias}", alias, StringComparison.Ordinal);
    }

    internal static readonly Reason[] Definitions =
    [
        new(1 << 0, "excludedByDate", "Excluded by date", "{alias}.[ExcludedByDate] = 1", "ExcludedByDate"),
        new(1 << 1, "aeAccountInUcPath", "AE account also in UCPath", "{alias}.[Source] = N'AE' AND {alias}.[AccountInUcPath] = 1", "AeAccountInUcPath"),
        new(1 << 2, "ucPathAccountNotInAE", "UCPath account missing from AE chart", "{alias}.[Source] = N'UCP' AND {alias}.[AccountNotInAE] = 1", "UcPathAccountNotInAe"),
        new(1 << 3, "sfn:unresolved", "No SFN derived for this transaction", "{alias}.[Sfn] IS NULL", "ExpenseSfnUnresolved"),
        new(1 << 4, "account:531010", "UCPath account 531010 on a Hatch fund", "{alias}.[Source] = N'UCP' AND {alias}.[Account531010OnHatchFund] = 1", "Account531010"),
        new(1 << 5, "sfn:204NotOnProjectList", "SFN 204 project not on the project list", "{alias}.[Sfn204NotOnProjectList] = 1", "Sfn204NotOnProjectList"),
        new(1 << 6, "financialDept:excluded", "Excluded by financial department", "{alias}.[FinancialDeptIncludeInReport] = 0", AggregatePrefix: null),
        new(1 << 7, "financialDept:unclassified", "Unclassified financial department", "{alias}.[FinancialDeptIncludeInReport] IS NULL", AggregatePrefix: null),
        new(1 << 8, "fund:excluded", "Excluded by fund", "{alias}.[FundIncludeInReport] = 0", AggregatePrefix: null),
        new(1 << 9, "fund:unclassified", "Unclassified fund", "{alias}.[FundIncludeInReport] IS NULL", AggregatePrefix: null),
        new(1 << 10, "account:excluded", "Excluded by account", "{alias}.[AccountIncludeInReport] = 0", AggregatePrefix: null),
        new(1 << 11, "account:unclassified", "Unclassified account", "{alias}.[AccountIncludeInReport] IS NULL", AggregatePrefix: null),
        new(1 << 12, "activity:excluded", "Excluded by activity", "{alias}.[ActivityIncludeInReport] = 0", AggregatePrefix: null),
        new(1 << 13, "activity:unclassified", "Unclassified activity", "{alias}.[ActivityIncludeInReport] IS NULL", AggregatePrefix: null),
        new(1 << 14, "purpose:excluded", "Excluded by purpose", "COALESCE({alias}.[PurposeExempt], 0) = 0 AND {alias}.[PurposeIncludeInReport] = 0", AggregatePrefix: null),
        new(1 << 15, "purpose:unclassified", "Unclassified purpose", "COALESCE({alias}.[PurposeExempt], 0) = 0 AND {alias}.[PurposeIncludeInReport] IS NULL", AggregatePrefix: null),
    ];

    public static int BitForCode(string code) =>
        Definitions.FirstOrDefault(reason => string.Equals(reason.Code, code, StringComparison.OrdinalIgnoreCase))?.Bit ?? 0;
}
