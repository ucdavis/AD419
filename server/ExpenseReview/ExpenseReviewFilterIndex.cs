using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

// One distinct mix of filter values found in the cycle's transactions. A transaction with several
// exclusion reasons shows up once per reason; one with none has a null ExclusionReason.
public sealed class ExpenseReviewFilterCombo
{
    public string? Source { get; init; }
    public string? EntityCode { get; init; }
    public string? FinancialDeptCode { get; init; }
    public string? FundCode { get; init; }
    public string? AccountCode { get; init; }
    public string? AeProjectCode { get; init; }
    public string? AccountingPeriod { get; init; }
    public string? PurposeCode { get; init; }
    public string? ProgramCode { get; init; }
    public string? ActivityCode { get; init; }
    public string? Sfn { get; init; }
    public string? ExclusionReason { get; init; }
}

// Narrows the filter dropdowns to values that exist in transactions matching the other selected
// filters. Combos are stored as indexes into each dropdown's cycle-wide option list so a cycle's
// worth of them stays small in memory and each narrowing is one pass over an int array.
public sealed class ExpenseReviewFilterIndex
{
    private const int Missing = -1;

    // Order matches the ExpenseReviewFilterOptionsResponse constructor.
    private static readonly Field[] Fields =
    [
        new(options => options.Entities, filters => filters.Entity, combo => combo.EntityCode),
        new(options => options.FinancialDepts, filters => filters.FinancialDept, combo => combo.FinancialDeptCode),
        new(options => options.Funds, filters => filters.Fund, combo => combo.FundCode),
        new(options => options.Accounts, filters => filters.Account, combo => combo.AccountCode),
        new(options => options.AeProjects, filters => filters.AeProject, combo => combo.AeProjectCode),
        new(options => options.AccountingPeriods, filters => filters.AccountingPeriod, combo => combo.AccountingPeriod),
        new(options => options.Purposes, filters => filters.Purpose, combo => combo.PurposeCode),
        new(options => options.Programs, filters => filters.Program, combo => combo.ProgramCode),
        new(options => options.Activities, filters => filters.Activity, combo => combo.ActivityCode),
        new(options => options.Sfns, filters => filters.Sfn, combo => combo.Sfn),
        new(options => options.Sources, filters => filters.Source, combo => combo.Source),
        new(options => options.ExclusionReasons, filters => filters.ExclusionReason, combo => combo.ExclusionReason),
    ];

    private readonly IReadOnlyList<ExpenseReviewFilterOptionDto>[] _options;
    private readonly Dictionary<string, int>[] _optionIndexes;
    private readonly int[] _combos;
    private readonly int _comboCount;

    private ExpenseReviewFilterIndex(
        ExpenseReviewFilterOptionsResponse allOptions,
        IReadOnlyList<ExpenseReviewFilterOptionDto>[] options,
        Dictionary<string, int>[] optionIndexes,
        int[] combos,
        int comboCount)
    {
        AllOptions = allOptions;
        _options = options;
        _optionIndexes = optionIndexes;
        _combos = combos;
        _comboCount = comboCount;
    }

    public ExpenseReviewFilterOptionsResponse AllOptions { get; }

    public static ExpenseReviewFilterIndex Build(
        ExpenseReviewFilterOptionsResponse allOptions,
        IReadOnlyCollection<ExpenseReviewFilterCombo> combos)
    {
        var options = Fields.Select(field => field.Options(allOptions)).ToArray();
        var optionIndexes = options.Select(BuildOptionIndex).ToArray();

        var encoded = new int[combos.Count * Fields.Length];
        var offset = 0;
        foreach (var combo in combos)
        {
            for (var field = 0; field < Fields.Length; field++)
            {
                encoded[offset + field] = IndexOf(optionIndexes[field], Fields[field].ComboValue(combo));
            }

            offset += Fields.Length;
        }

        return new ExpenseReviewFilterIndex(allOptions, options, optionIndexes, encoded, combos.Count);
    }

    public ExpenseReviewFilterOptionsResponse Narrow(ExpenseReviewFilters filters)
    {
        var selected = SelectedMasks(filters);
        var activeFields = Enumerable.Range(0, Fields.Length)
            .Where(field => selected[field] != null)
            .ToArray();
        if (activeFields.Length == 0)
        {
            return AllOptions;
        }

        var allowed = _options.Select(options => new bool[options.Count]).ToArray();

        for (var combo = 0; combo < _comboCount; combo++)
        {
            var offset = combo * Fields.Length;
            var failedField = Missing;
            var failures = 0;

            foreach (var field in activeFields)
            {
                var value = _combos[offset + field];
                if (value == Missing || !selected[field]![value])
                {
                    failures++;
                    failedField = field;
                    if (failures > 1)
                    {
                        break;
                    }
                }
            }

            // A combo that matches every filter contributes to every dropdown. One that misses a
            // single filter still contributes to that filter's own dropdown, which ignores itself.
            if (failures == 0)
            {
                for (var field = 0; field < Fields.Length; field++)
                {
                    Allow(allowed[field], _combos[offset + field]);
                }
            }
            else if (failures == 1)
            {
                Allow(allowed[failedField], _combos[offset + failedField]);
            }
        }

        var narrowed = Enumerable.Range(0, Fields.Length)
            .Select(field => _options[field].Where((_, index) => allowed[field][index]).ToList())
            .ToArray();

        return new ExpenseReviewFilterOptionsResponse(
            narrowed[0],
            narrowed[1],
            narrowed[2],
            narrowed[3],
            narrowed[4],
            narrowed[5],
            narrowed[6],
            narrowed[7],
            narrowed[8],
            narrowed[9],
            narrowed[10],
            narrowed[11]);
    }

    private bool[]?[] SelectedMasks(ExpenseReviewFilters filters)
    {
        var masks = new bool[]?[Fields.Length];
        for (var field = 0; field < Fields.Length; field++)
        {
            var values = Fields[field].Selected(filters);
            if (values.Count == 0)
            {
                continue;
            }

            var mask = new bool[_options[field].Count];
            foreach (var value in values)
            {
                Allow(mask, IndexOf(_optionIndexes[field], value));
            }

            masks[field] = mask;
        }

        return masks;
    }

    private static Dictionary<string, int> BuildOptionIndex(IReadOnlyList<ExpenseReviewFilterOptionDto> options)
    {
        // SQL compares codes case-insensitively, so the dropdowns do too.
        var index = new Dictionary<string, int>(options.Count, StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < options.Count; i++)
        {
            index.TryAdd(options[i].Value, i);
        }

        return index;
    }

    private static int IndexOf(Dictionary<string, int> optionIndex, string? value)
    {
        if (value == null)
        {
            return Missing;
        }

        return optionIndex.TryGetValue(value, out var index) ? index : Missing;
    }

    private static void Allow(bool[] allowed, int value)
    {
        if (value != Missing)
        {
            allowed[value] = true;
        }
    }

    private sealed record Field(
        Func<ExpenseReviewFilterOptionsResponse, IReadOnlyList<ExpenseReviewFilterOptionDto>> Options,
        Func<ExpenseReviewFilters, IReadOnlyList<string>> Selected,
        Func<ExpenseReviewFilterCombo, string?> ComboValue);
}
