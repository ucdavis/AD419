using FluentAssertions;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public class ExpenseReviewFilterIndexTests
{
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
        ExclusionReason = reason,
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
