using Server.Models.ExpenseReview;

namespace Server.Assistant;

/// <summary>Columnar row shape sent to the model. Codes only; names come from the filter-options tool.</summary>
public static class ExpenseReviewAssistantTable
{
    public static readonly IReadOnlyList<string> Columns =
    [
        "id",
        "source",
        "amount",
        "included",
        "accountingPeriod",
        "sfn",
        "entity",
        "financialDept",
        "fund",
        "account",
        "aeProject",
        "purpose",
        "program",
        "activity",
        "exclusionReasons",
    ];

    public static object?[] ToRow(ExpenseReviewTransactionDto row) =>
    [
        row.Id,
        row.Source,
        row.Amount,
        row.Included,
        row.AccountingPeriod,
        row.Sfn,
        row.Entity.Code,
        row.FinancialDept.Code,
        row.Fund.Code,
        row.Account.Code,
        row.AeProject.Code,
        row.Purpose.Code,
        row.Program.Code,
        row.Activity.Code,
        row.ExclusionReasons.Select(reason => reason.Code).ToArray(),
    ];
}
