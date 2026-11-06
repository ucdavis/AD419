using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

// One mix of ordinary filter values, with its exclusion reasons encoded as bits.
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
    public int ExclusionReasonMask { get; init; }
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
    ];

    private static readonly int ReasonField = Fields.Length;
    private static readonly int Stride = ReasonField + 1;

    private readonly IReadOnlyList<ExpenseReviewFilterOptionDto>[] _options;
    private readonly Dictionary<string, int>[] _optionIndexes;
    private readonly int[] _combos;
    private readonly int[] _reasonBits;
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
        _reasonBits = allOptions.ExclusionReasons.Select(option => ExpenseReviewExclusionReasons.BitForCode(option.Value)).ToArray();
    }

    public ExpenseReviewFilterOptionsResponse AllOptions { get; }

    public static ExpenseReviewFilterIndex Build(
        ExpenseReviewFilterOptionsResponse allOptions,
        IReadOnlyCollection<ExpenseReviewFilterCombo> combos)
    {
        var options = Fields.Select(field => field.Options(allOptions)).Append(allOptions.ExclusionReasons).ToArray();
        var optionIndexes = Fields.Select(field => BuildOptionIndex(field.Options(allOptions))).ToArray();

        var encoded = new int[combos.Count * Stride];
        var offset = 0;
        foreach (var combo in combos)
        {
            for (var field = 0; field < Fields.Length; field++)
            {
                encoded[offset + field] = IndexOf(optionIndexes[field], Fields[field].ComboValue(combo));
            }

            encoded[offset + ReasonField] = combo.ExclusionReasonMask;
            offset += Stride;
        }

        return new ExpenseReviewFilterIndex(allOptions, options, optionIndexes, encoded, combos.Count);
    }

    public ExpenseReviewFilterOptionsResponse Narrow(ExpenseReviewFilters filters)
    {
        var selected = SelectedMasks(filters);
        var activeFields = Enumerable.Range(0, Fields.Length)
            .Where(field => selected[field] != null)
            .ToArray();
        var hasReasonSelection = filters.ExclusionReason.Count > 0;
        if (activeFields.Length == 0 && !hasReasonSelection)
        {
            return AllOptions;
        }

        var reasonSelection = filters.ExclusionReason.Aggregate(0,
            (mask, code) => mask | ExpenseReviewExclusionReasons.BitForCode(code));
        var allowed = _options.Select(options => new bool[options.Count]).ToArray();
        var allowedReasons = 0;

        for (var combo = 0; combo < _comboCount; combo++)
        {
            var offset = combo * Stride;
            var reasonFailed = hasReasonSelection && (_combos[offset + ReasonField] & reasonSelection) == 0;
            var failedField = reasonFailed ? ReasonField : Missing;
            var failures = reasonFailed ? 1 : 0;

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
                allowedReasons |= _combos[offset + ReasonField];
            }
            else if (failures == 1)
            {
                if (failedField == ReasonField)
                {
                    allowedReasons |= _combos[offset + ReasonField];
                }
                else
                {
                    Allow(allowed[failedField], _combos[offset + failedField]);
                }
            }
        }

        for (var reason = 0; reason < _reasonBits.Length; reason++)
        {
            allowed[ReasonField][reason] = (allowedReasons & _reasonBits[reason]) != 0;
        }

        var narrowed = Enumerable.Range(0, Stride)
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
            narrowed[ReasonField]);
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
