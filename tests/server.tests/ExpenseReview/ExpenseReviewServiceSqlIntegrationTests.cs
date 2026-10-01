using System.Text;
using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.ExpenseReview;
using Server.Models;
using Server.Models.ExpenseReview;
using Server.Tests.SqlIntegration;

namespace Server.Tests.ExpenseReview;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class ExpenseReviewServiceSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Transaction_queries_group_by_source_and_apply_filters_counts_sorting_and_filter_options()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        var cycle = Cycle();

        var all = await service.GetTransactionsAsync(cycle, Request(), CancellationToken.None);

        all.Counts.Should().BeEquivalentTo(new ExpenseReviewCountsDto(3, 2, 1));
        all.TotalCount.Should().Be(3);
        all.Rows.Should().HaveCount(3);
        all.Rows.Should().NotContain(row => row.Amount == 999m);

        var aeGroup = all.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Fund.Code == "F1").Subject;
        aeGroup.AccountingPeriod.Should().BeNull();
        aeGroup.Amount.Should().Be(125m);
        aeGroup.Included.Should().BeTrue();
        aeGroup.ExclusionReasons.Should().BeEmpty();
        aeGroup.Entity.Should().BeEquivalentTo(new ExpenseReviewCodeNameDto("3310", "Entity One"));
        aeGroup.FinancialDept.Name.Should().Be("Dept One");
        aeGroup.Fund.Name.Should().Be("Fund One");
        aeGroup.Account.Name.Should().Be("Account One");
        aeGroup.AeProject.Name.Should().Be("AE Project One");
        aeGroup.Purpose.Name.Should().Be("Purpose One");
        aeGroup.Program.Name.Should().Be("Program One");
        aeGroup.Activity.Name.Should().Be("Activity One");

        var ucPathGroup = all.Rows.Should().ContainSingle(row => row.Source == "UCP" && row.Fund.Code == "F1").Subject;
        ucPathGroup.AccountingPeriod.Should().BeNull();
        ucPathGroup.Amount.Should().Be(500m);
        ucPathGroup.Included.Should().BeTrue();

        var excludedGroup = all.Rows.Should().ContainSingle(row => row.Fund.Code == "F2").Subject;
        excludedGroup.Source.Should().Be("AE");
        excludedGroup.Amount.Should().Be(50m);
        excludedGroup.Included.Should().BeFalse();
        excludedGroup.ExclusionReasons.Should().ContainSingle(reason =>
            reason.Code == "fund:excluded" &&
            reason.Label == "Excluded by fund" &&
            reason.RowCount == 1 &&
            reason.Amount == 50m);

        var included = await service.GetTransactionsAsync(
            cycle,
            Request(
                includeState: ExpenseReviewIncludeState.Included,
                pageSize: 1,
                sortBy: "amount",
                sortDescending: true,
                filters: Filters(fund: ["F1"])),
            CancellationToken.None);

        included.TotalCount.Should().Be(2);
        included.PageCount.Should().Be(2);
        included.Rows.Select(row => row.Amount).Should().Equal(500m);

        var reasonFiltered = await service.GetTransactionsAsync(
            cycle,
            Request(filters: Filters(exclusionReason: ["fund:excluded"])),
            CancellationToken.None);
        reasonFiltered.TotalCount.Should().Be(1);
        reasonFiltered.Rows.Should().ContainSingle(row => row.Fund.Code == "F2");

        var periodFiltered = await service.GetTransactionsAsync(
            cycle,
            Request(filters: Filters(accountingPeriod: ["Oct-24"])),
            CancellationToken.None);
        periodFiltered.TotalCount.Should().Be(2);
        periodFiltered.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Fund.Code == "F1")
            .Which.Amount.Should().Be(100m);

        var periodSplit = await service.GetTransactionsAsync(
            cycle,
            Request(displayByPeriod: true, sortBy: "accountingPeriod", filters: Filters(fund: ["F1"])),
            CancellationToken.None);
        periodSplit.TotalCount.Should().Be(3);
        periodSplit.Rows.Should().ContainSingle(row =>
                row.Source == "AE" && row.AccountingPeriod == "Oct-24")
            .Which.Amount.Should().Be(100m);
        periodSplit.Rows.Should().ContainSingle(row =>
                row.Source == "AE" && row.AccountingPeriod == "Nov-24")
            .Which.Amount.Should().Be(25m);
        periodSplit.Rows.Should().ContainSingle(row =>
                row.Source == "UCP" && row.AccountingPeriod == "Nov-24")
            .Which.Amount.Should().Be(500m);

        var filters = await service.GetFilterOptionsAsync(cycle, CancellationToken.None);
        filters.Entities.Should().ContainSingle(option => option.Value == "3310" && option.Label == "3310 - Entity One");
        filters.FinancialDepts.Should().ContainSingle(option => option.Value == "D1" && option.Label == "D1 - Dept One");
        filters.Funds.Should().Contain(option => option.Value == "F1" && option.Label == "F1 - Fund One");
        filters.Accounts.Should().ContainSingle(option => option.Value == "A1" && option.Label == "A1 - Account One");
        filters.AeProjects.Should().ContainSingle(option => option.Value == "PR1" && option.Label == "PR1 - Project One");
        filters.AccountingPeriods.Select(option => option.Value).Should().Equal("Oct-24", "Nov-24");
        filters.Purposes.Should().ContainSingle(option => option.Value == "P1" && option.Label == "P1 - Purpose One");
        filters.Programs.Should().ContainSingle(option => option.Value == "PG1" && option.Label == "PG1 - Program One");
        filters.Activities.Should().ContainSingle(option => option.Value == "AC1" && option.Label == "AC1 - Activity One");
        filters.Sfns.Should().ContainSingle(option => option.Value == "201" && option.Label == "201 - Hatch");
        filters.Sources.Select(option => (option.Value, option.Label))
            .Should().Equal(("AE", "Aggie Enterprise"), ("UCP", "UCPath"));
        filters.ExclusionReasons.Should().ContainSingle(option =>
            option.Value == "fund:excluded" && option.Label == "Excluded by fund");
    }

    [Fact]
    public async Task Transaction_queries_explain_persisted_exclusion_flags()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.Counts.Should().BeEquivalentTo(new ExpenseReviewCountsDto(5, 2, 3));
        all.TotalCount.Should().Be(5);

        var aeIncludedGroup = all.Rows.Should().ContainSingle(row =>
            row.Source == "AE" &&
            row.Fund.Code == "F1" &&
            row.Included).Subject;
        aeIncludedGroup.Amount.Should().Be(125m);
        aeIncludedGroup.ExclusionReasons.Should().BeEmpty();

        var aeExcludedGroup = all.Rows.Should().ContainSingle(row =>
            row.Source == "AE" &&
            row.Fund.Code == "F1" &&
            !row.Included).Subject;
        aeExcludedGroup.Amount.Should().Be(803m);
        aeExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "excludedByDate" &&
            reason.Label == "Excluded by date" &&
            reason.RowCount == 1 &&
            reason.Amount == 401m);
        aeExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "aeAccountInUcPath" &&
            reason.Label == "AE account also in UCPath" &&
            reason.RowCount == 1 &&
            reason.Amount == 402m);

        var ucPathIncludedGroup = all.Rows.Should().ContainSingle(row =>
            row.Source == "UCP" &&
            row.Fund.Code == "F1" &&
            row.Included).Subject;
        ucPathIncludedGroup.Amount.Should().Be(500m);
        ucPathIncludedGroup.ExclusionReasons.Should().BeEmpty();

        var ucPathExcludedGroup = all.Rows.Should().ContainSingle(row =>
            row.Source == "UCP" &&
            row.Fund.Code == "F1" &&
            !row.Included).Subject;
        ucPathExcludedGroup.Amount.Should().Be(807m);
        ucPathExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "excludedByDate" &&
            reason.Label == "Excluded by date" &&
            reason.RowCount == 1 &&
            reason.Amount == 403m);
        ucPathExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "ucPathAccountNotInAE" &&
            reason.Label == "UCPath account missing from AE chart" &&
            reason.RowCount == 1 &&
            reason.Amount == 404m);

        var included = await service.GetTransactionsAsync(
            Cycle(),
            Request(
                ExpenseReviewIncludeState.Included,
                filters: Filters(fund: ["F1"])),
            CancellationToken.None);
        included.TotalCount.Should().Be(2);
        included.Rows.Should().OnlyContain(row => row.Included);
        included.Rows.Should().ContainSingle(row => row.Source == "AE").Which.Amount.Should().Be(125m);
        included.Rows.Should().ContainSingle(row => row.Source == "UCP").Which.Amount.Should().Be(500m);

        var excluded = await service.GetTransactionsAsync(
            Cycle(),
            Request(
                ExpenseReviewIncludeState.Excluded,
                filters: Filters(fund: ["F1"])),
            CancellationToken.None);
        excluded.TotalCount.Should().Be(2);
        excluded.Rows.Should().OnlyContain(row => !row.Included);
        excluded.Rows.Should().ContainSingle(row => row.Source == "AE").Which.Amount.Should().Be(803m);
        excluded.Rows.Should().ContainSingle(row => row.Source == "UCP").Which.Amount.Should().Be(807m);
    }

    [Fact]
    public async Task Reason_processing_preserves_multi_reason_filters_paging_and_csv_output()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMultiReasonTransactionAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var firstPage = await service.GetTransactionsAsync(
            Cycle(),
            Request(
                includeState: ExpenseReviewIncludeState.Excluded,
                page: 1,
                pageSize: 1,
                sortBy: "amount"),
            CancellationToken.None);

        firstPage.TotalCount.Should().Be(2);
        firstPage.PageCount.Should().Be(2);
        firstPage.Rows.Should().ContainSingle(row => row.Fund.Code == "F2")
            .Which.ExclusionReasons.Should().ContainSingle(reason => reason.Code == "fund:excluded");

        var secondPage = await service.GetTransactionsAsync(
            Cycle(),
            Request(
                includeState: ExpenseReviewIncludeState.Excluded,
                page: 2,
                pageSize: 1,
                sortBy: "amount"),
            CancellationToken.None);

        var multiReasonRow = secondPage.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-MULTI").Subject;
        multiReasonRow.Amount.Should().Be(405m);
        multiReasonRow.ExclusionReasons.Select(reason => reason.Code).Should().BeEquivalentTo(
            ["excludedByDate", "aeAccountInUcPath"]);

        var reasonFiltered = await service.GetTransactionsAsync(
            Cycle(),
            Request(filters: Filters(exclusionReason: ["excludedByDate"])),
            CancellationToken.None);

        var filteredRow = reasonFiltered.Rows.Should().ContainSingle().Subject;
        filteredRow.AeProject.Code.Should().Be("PR-MULTI");
        filteredRow.Amount.Should().Be(405m);
        filteredRow.ExclusionReasons.Select(reason => reason.Code).Should().BeEquivalentTo(
            ["excludedByDate", "aeAccountInUcPath"]);

        await using var output = new MemoryStream();
        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(filters: Filters(exclusionReason: ["excludedByDate"])),
            output,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray());
        csv.Should().Contain("405.00,Excluded,");
        csv.Should().Contain("Excluded by date · $405.00 · 1 row");
        csv.Should().Contain("AE account also in UCPath · $405.00 · 1 row");
    }

    [Fact]
    public async Task Classification_reason_counts_null_amount_rows_as_zero_dollars()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedNullAmountTransactionAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetTransactionsAsync(
            Cycle(),
            Request(filters: Filters(fund: ["F-NULL"])),
            CancellationToken.None);

        var row = response.Rows.Should().ContainSingle().Subject;
        row.Amount.Should().BeNull();
        row.ExclusionReasons.Should().ContainSingle(reason =>
            reason.Code == "fund:excluded" &&
            reason.RowCount == 1 &&
            reason.Amount == 0m);
    }

    [Fact]
    public async Task Transaction_queries_and_csv_exclude_zero_amount_groups_by_default()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedZeroAmountGroupAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var withoutZeroAmounts = await service.GetTransactionsAsync(
            Cycle(),
            Request(),
            CancellationToken.None);

        withoutZeroAmounts.Counts.Should().BeEquivalentTo(new ExpenseReviewCountsDto(3, 2, 1));
        withoutZeroAmounts.TotalCount.Should().Be(3);
        withoutZeroAmounts.Rows.Should().NotContain(row => row.Fund.Code == "F0");

        var withZeroAmounts = await service.GetTransactionsAsync(
            Cycle(),
            Request(includeZeroAmounts: true),
            CancellationToken.None);

        withZeroAmounts.Counts.Should().BeEquivalentTo(new ExpenseReviewCountsDto(4, 3, 1));
        withZeroAmounts.TotalCount.Should().Be(4);
        withZeroAmounts.Rows.Should().ContainSingle(row => row.Fund.Code == "F0")
            .Which.Amount.Should().Be(0m);

        await using var defaultCsv = new MemoryStream();
        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(),
            defaultCsv,
            CancellationToken.None);
        Encoding.UTF8.GetString(defaultCsv.ToArray()).Should().NotContain("F0 - Zero Fund");

        await using var csvWithZeroAmounts = new MemoryStream();
        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(includeZeroAmounts: true),
            csvWithZeroAmounts,
            CancellationToken.None);
        Encoding.UTF8.GetString(csvWithZeroAmounts.ToArray()).Should().Contain("F0 - Zero Fund");
    }

    [Fact]
    public async Task Transaction_queries_explain_missing_classifications_except_13u02_purpose()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMissingClassificationRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.Rows.Should().Contain(row =>
            row.FinancialDept.Code == "D-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Unclassified financial department"));
        all.Rows.Should().Contain(row =>
            row.Account.Code == "A-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Unclassified account"));
        all.Rows.Should().Contain(row =>
            row.Activity.Code == "AC-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Unclassified activity"));
        all.Rows.Should().Contain(row =>
            row.Purpose.Code == "P-MISSING" &&
            row.Fund.Code == "F1" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Unclassified purpose"));
        all.Rows.Should().Contain(row =>
            row.Purpose.Code == "P-MISSING" &&
            row.Fund.Code == "13U02" &&
            row.Included &&
            row.ExclusionReasons.Count == 0);
    }

    [Fact]
    public async Task Transaction_csv_export_applies_filters_include_state_and_sort_without_page_size_limit()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        await using var output = new MemoryStream();

        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(
                includeState: ExpenseReviewIncludeState.Included,
                pageSize: 1,
                sortBy: "amount",
                sortDescending: true,
                filters: Filters(fund: ["F1"])),
            output,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray()).TrimStart('\ufeff');
        var lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        lines.Should().HaveCount(3);
        lines[0].Should().Be(
            "Source,Entity,Fund,Financial Dept,Account,Purpose,Program,Project,Activity,SFN,Amount,Include State,Exclusion Reasons");
        lines[1].Should().StartWith("UCP,").And.Contain(",500.00,Included,");
        lines[2].Should().StartWith("AE,").And.Contain(",125.00,Included,");
    }

    [Fact]
    public async Task Transaction_csv_export_splits_mixed_include_state_groups()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        await using var output = new MemoryStream();

        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(
                sortBy: "amount",
                filters: Filters(fund: ["F1"], source: ["AE"])),
            output,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray()).TrimStart('\ufeff');
        var lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        lines.Should().HaveCount(3);
        lines.Should().Contain(
            "AE,3310 - Entity One,F1 - Fund One,D1 - Dept One,A1 - Account One,P1 - Purpose One,PG1 - Program One,PR1 - AE Project One,AC1 - Activity One,201 - Hatch,125.00,Included,");
        lines.Should().Contain(line =>
            line.Contains("803.00,Excluded,", StringComparison.Ordinal) &&
            line.Contains("AE account also in UCPath · $402.00 · 1 row", StringComparison.Ordinal) &&
            line.Contains("Excluded by date · $401.00 · 1 row", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Transaction_queries_use_derived_expense_sfn_and_exclude_unresolved_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedDerivedSfnRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        var stateRow = all.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-STATE").Subject;
        stateRow.Sfn.Should().Be("220");
        stateRow.SfnLabel.Should().Be("State Appropriations");
        stateRow.Included.Should().BeTrue();
        stateRow.ExclusionReasons.Should().BeEmpty();

        var resolvedRow = all.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-204").Subject;
        resolvedRow.Sfn.Should().Be("204");
        resolvedRow.Included.Should().BeTrue();
        resolvedRow.ExclusionReasons.Should().BeEmpty();

        var unresolvedRow = all.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-UNMAPPED").Subject;
        unresolvedRow.Sfn.Should().BeNull();
        unresolvedRow.Included.Should().BeFalse();
        unresolvedRow.ExclusionReasons.Should().ContainSingle(reason =>
            reason.Code == "sfn:unresolved" &&
            reason.Label == "No SFN derived for this transaction" &&
            reason.RowCount == 1 &&
            reason.Amount == 77m);

        var reasonFiltered = await service.GetTransactionsAsync(
            Cycle(),
            Request(filters: Filters(exclusionReason: ["sfn:unresolved"])),
            CancellationToken.None);
        reasonFiltered.TotalCount.Should().Be(1);
        reasonFiltered.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-UNMAPPED");

        var sfnFiltered = await service.GetTransactionsAsync(
            Cycle(),
            Request(filters: Filters(sfn: ["220"])),
            CancellationToken.None);
        sfnFiltered.Rows.Should().ContainSingle(row => row.AeProject.Code == "PR-STATE");

        var filters = await service.GetFilterOptionsAsync(Cycle(), CancellationToken.None);
        filters.Sfns.Select(option => option.Value).Should().BeEquivalentTo(["201", "204", "220"]);
        filters.Sfns.Should().NotContain(option => option.Value == "Multiple");
        filters.ExclusionReasons.Should().Contain(option =>
            option.Value == "sfn:unresolved" && option.Label == "No SFN derived for this transaction");
    }

    [Fact]
    public async Task Unmatched_job_codes_group_in_window_ucpath_rows_without_an_fte_line_by_reason()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetUnmatchedJobCodesAsync(Cycle(), CancellationToken.None);

        response.FiscalYear.Should().Be("FY25");
        // Ordered by summed FTE descending. The NULL job code group is the base
        // scenario's two in-window rows (0.75) plus JC-MISSING (0.03).
        response.Rows.Select(row => (row.JobCode, row.Reason)).Should().Equal(
            (null, "missingJobCode"),
            ("0000", "noTitle"),
            ("5678", "titleHasNoStaffType"),
            ("9999", "staffTypeHasNoLine"),
            ("7777", "staffTypeNotFound"));

        var noTitle = response.Rows.Single(row => row.JobCode == "0000");
        noTitle.TitleName.Should().BeNull();
        noTitle.StaffTypeCode.Should().BeNull();
        noTitle.RowCount.Should().Be(2);
        noTitle.EmployeeCount.Should().Be(1);
        noTitle.Amount.Should().Be(30m);
        noTitle.Fte.Should().Be(0.300000m);

        var noStaffType = response.Rows.Single(row => row.JobCode == "5678");
        noStaffType.TitleName.Should().Be("Unclassified title");
        noStaffType.StaffTypeCode.Should().BeNull();

        var noLine = response.Rows.Single(row => row.JobCode == "9999");
        noLine.TitleName.Should().Be("Title with lineless staff type");
        noLine.StaffTypeCode.Should().Be("NOLINE");

        var notFound = response.Rows.Single(row => row.JobCode == "7777");
        notFound.TitleName.Should().Be("Title with dangling staff type");
        notFound.StaffTypeCode.Should().Be("GHOST");
        notFound.RowCount.Should().Be(1);

        response.Rows.Should().NotContain(row => row.JobCode == "1234");
    }

    [Fact]
    public async Task Transaction_queries_exclude_ucpath_account_531010_on_hatch_funds_with_a_reason()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedAccount531010RowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        var hatchRow = all.Rows.Should().ContainSingle(row => row.Source == "UCP" && row.Account.Code == "531010" && row.Fund.Code == "F1").Subject;
        hatchRow.Included.Should().BeFalse();
        hatchRow.ExclusionReasons.Should().ContainSingle(reason =>
            reason.Code == "account:531010" &&
            reason.Label == "UCPath account 531010 on a Hatch fund" &&
            reason.RowCount == 1 &&
            reason.Amount == 61m);

        var grantRow = all.Rows.Should().ContainSingle(row => row.Source == "UCP" && row.Account.Code == "531010" && row.Fund.Code == "F204").Subject;
        grantRow.Included.Should().BeTrue();
        grantRow.ExclusionReasons.Should().BeEmpty();

        var aeRow = all.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Account.Code == "531010").Subject;
        aeRow.Included.Should().BeTrue();

        var filters = await service.GetFilterOptionsAsync(Cycle(), CancellationToken.None);
        filters.ExclusionReasons.Should().Contain(option =>
            option.Value == "account:531010" && option.Label == "UCPath account 531010 on a Hatch fund");
    }

    private async Task SeedAccount531010RowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('Fund', 'F204', 'Grant fund', 1, '204'),
                ('Account', '531010', 'Academic salary', 1, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-531010-HATCH', '3310', 'F1',   'D1', 'D1', '531010', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000011', 'POS00011', 10.000000, 61.00, 0.050000, '2024-11-30', 'S', 2025, '5', 0, 0, 0, 0),
                ('UCP-531010-GRANT', '3310', 'F204', 'D1', 'D1', '531010', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000012', 'POS00012', 10.000000, 62.00, 0.050000, '2024-11-30', 'S', 2025, '5', 0, 0, 0, 0);

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F1', 'D1', '531010', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Academic salary', 'Purpose One', 'Program One', 'AE 531010', 'Activity One',
                 'Oct-24', 63.00, 0, 0);
            """);
    }

    private async Task SeedUnmatchedJobCodeRowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description])
            VALUES ('PROF', '241', 'Professors'), ('NOLINE', NULL, 'Not yet classified');

            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name])
            VALUES
                ('1234', 'PROF',   'Professor'),
                ('5678', NULL,     'Unclassified title'),
                ('9999', 'NOLINE', 'Title with lineless staff type'),
                ('7777', 'GHOST',  'Title with dangling staff type');

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-MATCHED',        '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000001', 'POS1', '1234', 10, 10.00, 0.100000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-NO-TITLE-A',     '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 10.00, 0.100000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-NO-TITLE-B',     '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 20, 20.00, 0.200000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0),
                ('JC-NO-TITLE-OLD',   '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 99.00, 0.100000, '2023-11-15', 'S', 2024, '5', 0, 0, 1, 0),
                ('JC-NO-STAFF-TYPE',  '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000003', 'POS3', '5678', 10, 10.00, 0.050000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-NO-LINE',        '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000004', 'POS4', '9999', 10, 10.00, 0.040000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-MISSING',        '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000005', 'POS5', NULL,   10, 10.00, 0.030000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STAFF-TYPE-MISSING', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000006', 'POS6', '7777', 10, 10.00, 0.020000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                -- Flagged rows are in window but already excluded; they must not count.
                ('JC-NO-TITLE-DATE-FLAG',    '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 50.00, 0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 1, 0),
                ('JC-NO-TITLE-ACCOUNT-FLAG', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 60.00, 0.600000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 1);
            """);
    }

    private async Task SeedDerivedSfnRowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label])
            VALUES ('220', 'State Appropriations'), ('204', 'Contracts and Grants');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('Fund', '13U02',  'State Appropriations', 1, '201'),
                ('Fund', 'FMULTI', 'Grant Fund',           1, 'Multiple');

            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES ('1000001', 'CA-D-ABC-1001-CG', 1, '204', 'PR-204');

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', '13U02', 'D1', 'A1', 'P1', 'PG1', 'PR-STATE', 'AC1',
                 'Entity One', 'State Appropriations', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'State Project', 'Activity One',
                 'Oct-24', 75.00, 0, 0),
                ('3310', 'FMULTI', 'D1', 'A1', 'P1', 'PG1', 'PR-204', 'AC1',
                 'Entity One', 'Grant Fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', '204 Project', 'Activity One',
                 'Oct-24', 76.00, 0, 0),
                ('3310', 'FMULTI', 'D1', 'A1', 'P1', 'PG1', 'PR-UNMAPPED', 'AC1',
                 'Entity One', 'Grant Fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Unmapped Grant Project', 'Activity One',
                 'Oct-24', 77.00, 0, 0);
            """);
    }

    private async Task SeedExpenseReviewScenarioAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label])
            VALUES ('201', 'Hatch');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1', 'Dept One', 1, NULL),
                ('Fund', 'F1', 'Fund One', 1, '201'),
                ('Fund', 'F2', 'Fund Two', 0, '201'),
                ('Account', 'A1', 'Account One', 1, NULL),
                ('Activity', 'AC1', 'Activity One', 1, NULL),
                ('Purpose', 'P1', 'Purpose One', 1, NULL),
                ('Ern', 'E01', 'Regular Pay', 1, NULL);

            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code], [Description], [ValueDesc])
            VALUES
                ('Entity', '3310', 'Entity Fallback', 'Entity One'),
                ('FinancialDepartment', 'D1', 'Financial Dept Fallback', 'Dept One'),
                ('Fund', 'F1', 'Fund Fallback', 'Fund One'),
                ('Fund', 'F2', 'Fund Two', 'Fund Two'),
                ('Account', 'A1', 'Account Fallback', 'Account One'),
                ('Project', 'PR1', 'Project Fallback', 'Project One'),
                ('Purpose', 'P1', 'Purpose Fallback', 'Purpose One'),
                ('Program', 'PG1', 'Program Fallback', 'Program One'),
                ('Activity', 'AC1', 'Activity Fallback', 'Activity One');

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'AE Project One', 'Activity One',
                 'Oct-24', 100.00, 0, 0),
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'AE Project One', 'Activity One',
                 'Nov-24', 25.00, 0, 0),
                ('3310', 'F2', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund Two', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Excluded Fund Project', 'Activity One',
                 'Oct-24', 50.00, 0, 0),
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Outside Project', 'Activity One',
                 'Oct-23', 999.00, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-INCLUDED', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000001', 'POS00001', 80.000000, 200.00, 0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('UCP-ERN-MISSING', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E02',
                 '20000002', 'POS00002', 40.000000, 300.00, 0.250000, '2024-11-30', 'S', 2025, '5', 0, 0, 0, 0),
                ('UCP-OUTSIDE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000003', 'POS00003', 40.000000, 999.00, 0.250000, '2023-11-30', 'S', 2024, '5', 0, 0, 0, 0);
            """);
    }

    private async Task SeedZeroAmountGroupAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Fund', 'F0', 'Zero Fund', 1, '201');

            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code], [Description], [ValueDesc])
            VALUES ('Fund', 'F0', 'Zero Fund', 'Zero Fund');

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F0', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Zero Fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Zero Group', 'Activity One',
                 'Dec-24', 10.00, 0, 0),
                ('3310', 'F0', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Zero Fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Zero Group', 'Activity One',
                 'Dec-24', -10.00, 0, 0);
            """);
    }

    private async Task SeedPersistedExclusionFlagRowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'AE Flag Excluded', 'Activity One',
                 'Oct-24', 401.00, 1, 0),
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'AE Account In UCPath', 'Activity One',
                 'Oct-24', 402.00, 0, 1);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-FLAG-EXCLUDED', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000004', 'POS00004', 10.000000, 403.00, 0.050000, '2024-11-30', 'S', 2025, '5', 0, 0, 1, 0),
                ('UCP-ACCOUNT-NOT-AE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000005', 'POS00005', 10.000000, 404.00, 0.050000, '2024-11-30', 'S', 2025, '5', 0, 0, 0, 1);
            """);
    }

    private async Task SeedMultiReasonTransactionAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR-MULTI', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Multi Reason Project', 'Activity One',
                 'Oct-24', 405.00, 1, 1);
            """);
    }

    private async Task SeedNullAmountTransactionAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Fund', 'F-NULL', 'Null Amount Fund', 0, '201');

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F-NULL', 'D1', 'A1', 'P1', 'PG1', 'PR-NULL', 'AC1',
                 'Entity One', 'Null Amount Fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Null Amount Project', 'Activity One',
                 'Oct-24', NULL, 0, 0);
            """);
    }

    private async Task SeedMissingClassificationRowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Fund', '13U02', 'UC ANR Federal Flowthrough', 1, '201');

            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                 [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('3310', 'F1', 'D-MISSING', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Missing Dept', 'Account One', 'Purpose One', 'Program One', 'Missing Financial Dept', 'Activity One',
                 'Oct-24', 511.00, 0, 0),
                ('3310', 'F1', 'D1', 'A-MISSING', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Missing Account', 'Purpose One', 'Program One', 'Missing Account', 'Activity One',
                 'Oct-24', 512.00, 0, 0),
                ('3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC-MISSING',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Missing Activity', 'Missing Activity',
                 'Oct-24', 513.00, 0, 0),
                ('3310', 'F1', 'D1', 'A1', 'P-MISSING', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Missing Purpose', 'Program One', 'Missing Purpose Non-13U02', 'Activity One',
                 'Oct-24', 514.00, 0, 0),
                ('3310', '13U02', 'D1', 'A1', 'P-MISSING', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'UC ANR Federal Flowthrough', 'Dept One', 'Account One', 'Missing Purpose', 'Program One', 'Missing Purpose 13U02', 'Activity One',
                 'Oct-24', 515.00, 0, 0);
            """);
    }

    private static ExpenseReviewTransactionsRequest Request(
        ExpenseReviewIncludeState includeState = ExpenseReviewIncludeState.All,
        int page = 1,
        int pageSize = 50,
        string sortBy = ExpenseReviewRequestParser.DefaultSortBy,
        bool sortDescending = false,
        bool displayByPeriod = false,
        bool includeZeroAmounts = false,
        ExpenseReviewFilters? filters = null) =>
        new(includeState, page, pageSize, sortBy, sortDescending, displayByPeriod, includeZeroAmounts, filters ?? Filters());

    private static ExpenseReviewFilters Filters(
        IReadOnlyList<string>? entity = null,
        IReadOnlyList<string>? financialDept = null,
        IReadOnlyList<string>? fund = null,
        IReadOnlyList<string>? account = null,
        IReadOnlyList<string>? aeProject = null,
        IReadOnlyList<string>? accountingPeriod = null,
        IReadOnlyList<string>? purpose = null,
        IReadOnlyList<string>? program = null,
        IReadOnlyList<string>? activity = null,
        IReadOnlyList<string>? sfn = null,
        IReadOnlyList<string>? source = null,
        IReadOnlyList<string>? exclusionReason = null) =>
        new(
            entity ?? [],
            financialDept ?? [],
            fund ?? [],
            account ?? [],
            aeProject ?? [],
            accountingPeriod ?? [],
            purpose ?? [],
            program ?? [],
            activity ?? [],
            sfn ?? [],
            source ?? [],
            exclusionReason ?? []);

    private static FiscalYearCycle Cycle()
    {
        FiscalYearCycle.TryParse("FY25", out var cycle).Should().BeTrue();
        return cycle!;
    }

    private IConfiguration Configuration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
            })
            .Build();
}
