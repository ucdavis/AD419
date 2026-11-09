using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewFilterIndexTests
{
    [Fact]
    public void Reasons_have_unique_single_bits_and_case_insensitive_codes()
    {
        var codes = new[] { "excludedByDate", "aeAccountInUcPath", "ucPathAccountNotInAE", "sfn:unresolved",
            "account:531010", "sfn:204NotOnProjectList", "financialDept:excluded", "financialDept:unclassified",
            "fund:excluded", "fund:unclassified", "account:excluded", "account:unclassified", "activity:excluded",
            "activity:unclassified", "purpose:excluded", "purpose:unclassified" };
        var bits = codes.Select(ExpenseReviewExclusionReasons.BitForCode).ToArray();
        bits.Should().OnlyHaveUniqueItems();
        bits.Should().OnlyContain(bit => bit > 0 && (bit & (bit - 1)) == 0);
        foreach (var code in codes)
        {
            ExpenseReviewExclusionReasons.BitForCode(code.ToUpperInvariant())
                .Should().Be(ExpenseReviewExclusionReasons.BitForCode(code));
        }
        ExpenseReviewExclusionReasons.BitForCode("unknown").Should().Be(0);
    }

    [Fact]
    public void Narrow_without_filters_returns_every_option_in_the_cycle()
    {
        var index = Index();

        var options = index.Narrow(ExpenseReviewFilters.None);

        options.Should().BeSameAs(index.AllOptions);
    }

    [Fact]
    public void Narrow_limits_other_dropdowns_to_values_in_the_selected_dept()
    {
        var options = Index().Narrow(Filters(financialDept: ["D1"]));

        Values(options.Funds).Should().Equal("F1", "F2");
        Values(options.Accounts).Should().Equal("A1");
        Values(options.Sources).Should().Equal("AE");
    }

    [Fact]
    public void Narrow_keeps_every_value_of_a_dropdown_that_is_only_filtered_by_itself()
    {
        var options = Index().Narrow(Filters(financialDept: ["D1"]));

        Values(options.FinancialDepts).Should().Equal("D1", "D2");
    }

    [Fact]
    public void Narrow_limits_each_dropdown_by_the_selections_in_the_other_dropdowns()
    {
        var options = Index().Narrow(Filters(financialDept: ["D2"], fund: ["F1"]));

        Values(options.FinancialDepts).Should().Equal("D1");
        Values(options.Funds).Should().Equal("F3");
        Values(options.Accounts).Should().BeEmpty();
    }

    [Fact]
    public void Narrow_matches_any_selected_value_within_a_dropdown()
    {
        var options = Index().Narrow(Filters(fund: ["F2", "F3"]));

        Values(options.FinancialDepts).Should().Equal("D1", "D2");
        Values(options.Accounts).Should().Equal("A1", "A2");
    }

    [Fact]
    public void Narrow_limits_dropdowns_to_rows_with_the_selected_exclusion_reason()
    {
        var options = Index().Narrow(Filters(exclusionReason: ["fund:excluded"]));

        Values(options.Funds).Should().Equal("F2");
        Values(options.ExclusionReasons).Should().Equal("fund:excluded", "sfn:unresolved");
    }

    [Fact]
    public void Narrow_limits_exclusion_reasons_to_the_selected_fund()
    {
        var options = Index().Narrow(Filters(fund: ["F3"]));

        Values(options.ExclusionReasons).Should().Equal("sfn:unresolved");
    }

    [Fact]
    public void Narrow_matches_selected_values_regardless_of_case()
    {
        var options = Index().Narrow(Filters(financialDept: ["d2"], source: ["ucp"]));

        Values(options.Funds).Should().Equal("F3");
    }

    [Fact]
    public void Narrow_leaves_out_rows_missing_a_value_for_a_filtered_dropdown()
    {
        var options = Index().Narrow(Filters(aeProject: ["PR1"]));

        Values(options.Funds).Should().Equal("F1");
    }

    [Fact]
    public void Narrow_keeps_labels_and_order_from_the_cycle_wide_options()
    {
        var options = Index().Narrow(Filters(financialDept: ["D1"]));

        options.Funds.Should().Equal(
            new ExpenseReviewFilterOptionDto("F1", "F1 label"),
            new ExpenseReviewFilterOptionDto("F2", "F2 label"));
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 0)]
    [InlineData(0, 1)]
    [InlineData(1, 1)]
    public void Masks_preserve_reasonless_single_and_multiple_reasons(int fund, int unresolved)
    {
        var mask = fund * ExpenseReviewExclusionReasons.BitForCode("fund:excluded")
            | unresolved * ExpenseReviewExclusionReasons.BitForCode("sfn:unresolved");
        var combo = new ExpenseReviewFilterCombo { FundCode = "F1", ExclusionReasonMask = mask };
        var options = new ExpenseReviewFilterOptionsResponse([], [], Options("F1"), [], [], [], [], [], [], [], [],
            Options("fund:excluded", "sfn:unresolved"));
        var index = ExpenseReviewFilterIndex.Build(options, [combo]);
        var selected = index.Narrow(Filters(exclusionReason: ["FUND:EXCLUDED", "sfn:unresolved", "unknown"]));
        Values(selected.Funds).Should().Equal(mask == 0 ? [] : new[] { "F1" });
        Values(selected.ExclusionReasons).Should().Equal(new[] { "fund:excluded", "sfn:unresolved" }
            .Where(code => (mask & ExpenseReviewExclusionReasons.BitForCode(code)) != 0));
        index.Narrow(Filters(exclusionReason: ["unknown"])).Funds.Should().BeEmpty();
        index.Narrow(Filters(fund: ["unknown"])).Funds.Should().Equal(options.Funds);
    }

    [Fact]
    public void Narrow_handles_repeated_ordinary_values_and_reasonless_rows()
    {
        var options = new ExpenseReviewFilterOptionsResponse([], [], Options("F1", "F2"), [], [], [], [], [], [], [], [],
            Options("fund:excluded", "sfn:unresolved"));
        var excluded = ExpenseReviewExclusionReasons.BitForCode("fund:excluded");
        var unresolved = ExpenseReviewExclusionReasons.BitForCode("sfn:unresolved");
        var index = ExpenseReviewFilterIndex.Build(options,
        [
            new() { FundCode = "F1" },
            new() { FundCode = "F1", ExclusionReasonMask = excluded },
            new() { FundCode = "F1", ExclusionReasonMask = excluded },
            new() { FundCode = "F1", ExclusionReasonMask = unresolved },
            new() { FundCode = "F2" },
        ]);

        Values(index.Narrow(Filters(exclusionReason: ["fund:excluded"])).Funds).Should().Equal("F1");
        Values(index.Narrow(Filters(fund: ["F1"])).ExclusionReasons).Should().Equal("fund:excluded", "sfn:unresolved");
        index.Narrow(Filters(fund: ["F2"])).ExclusionReasons.Should().BeEmpty();
        Values(index.Narrow(Filters(fund: ["F2"])).Funds).Should().Equal("F1", "F2");
    }

    [Fact]
    public void Narrow_matches_expanded_reference_rows_for_all_fields_nulls_case_and_unknown_selections()
    {
        var random = new Random(419);
        var reasonCodes = new[] { "fund:excluded", "sfn:unresolved", "excludedByDate" };
        var filterProperties = new[] { "Entity", "FinancialDept", "Fund", "Account", "AeProject", "AccountingPeriod", "Purpose", "Program", "Activity", "Sfn", "Source", "ExclusionReason" };
        var optionProperties = new[] { "Entities", "FinancialDepts", "Funds", "Accounts", "AeProjects", "AccountingPeriods", "Purposes", "Programs", "Activities", "Sfns", "Sources", "ExclusionReasons" };
        var options = new ExpenseReviewFilterOptionsResponse(Options("0", "1"), Options("0", "1"), Options("0", "1"),
            Options("0", "1"), Options("0", "1"), Options("0", "1"), Options("0", "1"), Options("0", "1"),
            Options("0", "1"), Options("0", "1"), Options("0", "1"), Options(reasonCodes));
        var combos = new List<ExpenseReviewFilterCombo>();
        var expanded = new List<string?[]>();
        for (var row = 0; row < 100; row++)
        {
            var values = Enumerable.Range(0, 11).Select(_ => random.Next(3) == 2 ? null : random.Next(2).ToString()).ToArray();
            var reasons = reasonCodes.Where(_ => random.Next(2) == 1).ToArray();
            var combo = new ExpenseReviewFilterCombo
            {
                EntityCode = values[0], FinancialDeptCode = values[1], FundCode = values[2], AccountCode = values[3],
                AeProjectCode = values[4], AccountingPeriod = values[5], PurposeCode = values[6], ProgramCode = values[7],
                ActivityCode = values[8], Sfn = values[9], Source = values[10],
                ExclusionReasonMask = reasons.Aggregate(0, (mask, code) => mask | ExpenseReviewExclusionReasons.BitForCode(code)),
            };
            combos.Add(combo);
            foreach (var reason in reasons.Length == 0 ? new string?[] { null } : reasons)
            {
                expanded.Add([.. values, reason]);
            }
        }
        var index = ExpenseReviewFilterIndex.Build(options, combos);
        for (var selection = 0; selection < 100; selection++)
        {
            var filters = ExpenseReviewFilters.None with { };
            var selected = new string[12][];
            for (var field = 0; field < 12; field++)
            {
                var possible = field == 11 ? reasonCodes : ["0", "1"];
                selected[field] = selection == 0 ? [] : possible.Append("unknown").Where(_ => random.Next(4) == 0).Select(value => value.ToUpperInvariant()).ToArray();
                typeof(ExpenseReviewFilters).GetProperty(filterProperties[field])!.SetValue(filters, selected[field]);
            }
            var actual = index.Narrow(filters);
            for (var field = 0; field < 12; field++)
            {
                var property = typeof(ExpenseReviewFilterOptionsResponse).GetProperty(optionProperties[field])!;
                var all = (IReadOnlyList<ExpenseReviewFilterOptionDto>)property.GetValue(options)!;
                var expected = all.Where(option => expanded.Any(row =>
                    string.Equals(row[field], option.Value, StringComparison.OrdinalIgnoreCase) &&
                    Enumerable.Range(0, 12).All(other => other == field || selected[other].Length == 0 ||
                        selected[other].Contains(row[other], StringComparer.OrdinalIgnoreCase)))).ToArray();
                property.GetValue(actual).Should().BeEquivalentTo(expected, comparison => comparison.WithStrictOrdering());
            }
        }
    }

    // D1 holds AE rows on funds F1 and F2 (F2 is excluded by fund). D2 holds a UCPath row on F3
    // with no SFN, and F1 also shows up in D1 on a row with no project.
    private static ExpenseReviewFilterIndex Index() =>
        ExpenseReviewFilterIndex.Build(
            new ExpenseReviewFilterOptionsResponse(
                Entities: Options("3310"),
                FinancialDepts: Options("D1", "D2"),
                Funds: Options("F1", "F2", "F3"),
                Accounts: Options("A1", "A2"),
                AeProjects: Options("PR1"),
                AccountingPeriods: Options("Oct-24", "Nov-24"),
                Purposes: Options("P1"),
                Programs: Options("PG1"),
                Activities: Options("AC1"),
                Sfns: Options("201"),
                Sources: Options("AE", "UCP"),
                ExclusionReasons: Options("fund:excluded", "sfn:unresolved")),
            [
                Combo("AE", "D1", "F1", "A1", aeProject: "PR1", sfn: "201"),
                Combo("AE", "D1", "F1", "A1", aeProject: null, sfn: "201", period: "Nov-24"),
                Combo("AE", "D1", "F2", "A1", aeProject: null, sfn: null, reason: "fund:excluded"),
                Combo("AE", "D1", "F2", "A1", aeProject: null, sfn: null, reason: "sfn:unresolved"),
                Combo("UCP", "D2", "F3", "A2", aeProject: null, sfn: null, reason: "sfn:unresolved"),
            ]);

    private static ExpenseReviewFilterCombo Combo(
        string source,
        string financialDept,
        string fund,
        string account,
        string? aeProject,
        string? sfn,
        string period = "Oct-24",
        string? reason = null) => new()
    {
        Source = source,
        EntityCode = "3310",
        FinancialDeptCode = financialDept,
        FundCode = fund,
        AccountCode = account,
        AeProjectCode = aeProject,
        AccountingPeriod = period,
        PurposeCode = "P1",
        ProgramCode = "PG1",
        ActivityCode = "AC1",
        Sfn = sfn,
        ExclusionReasonMask = reason == null ? 0 : ExpenseReviewExclusionReasons.BitForCode(reason),
    };

    private static IReadOnlyList<ExpenseReviewFilterOptionDto> Options(params string[] values) =>
        values.Select(value => new ExpenseReviewFilterOptionDto(value, $"{value} label")).ToList();

    private static IEnumerable<string> Values(IEnumerable<ExpenseReviewFilterOptionDto> options) =>
        options.Select(option => option.Value);

    private static ExpenseReviewFilters Filters(
        IReadOnlyList<string>? financialDept = null,
        IReadOnlyList<string>? fund = null,
        IReadOnlyList<string>? aeProject = null,
        IReadOnlyList<string>? source = null,
        IReadOnlyList<string>? exclusionReason = null) =>
        ExpenseReviewFilters.None with
        {
            FinancialDept = financialDept ?? [],
            Fund = fund ?? [],
            AeProject = aeProject ?? [],
            Source = source ?? [],
            ExclusionReason = exclusionReason ?? [],
        };
}
