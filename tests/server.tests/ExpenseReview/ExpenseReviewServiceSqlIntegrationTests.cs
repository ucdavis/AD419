using System.Text;
using System.Text.Json;
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
public sealed partial class ExpenseReviewServiceSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Theory]
    [InlineData("AE", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("UCP", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("AE,UCP", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("unknown", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("AE,unknown", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("UCP,unknown", false, false, ExpenseReviewIncludeState.All)]
    [InlineData("AE", true, false, ExpenseReviewIncludeState.Included)]
    [InlineData("UCP", true, true, ExpenseReviewIncludeState.All)]
    [InlineData("AE", false, true, ExpenseReviewIncludeState.Excluded)]
    public async Task Source_shapes_preserve_grid_summary_export_and_pagination_semantics(
        string source, bool byPeriod, bool includeZero, ExpenseReviewIncludeState includeState)
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMultiReasonTransactionAsync();
        await SeedZeroAmountGroupAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());
        var sources = source.Split(',', StringSplitOptions.RemoveEmptyEntries);
        var filters = Filters(source: sources);
        var request = Request(includeState: includeState, pageSize: 500, displayByPeriod: byPeriod,
            includeZeroAmounts: includeZero, filters: filters);
        // An extra unknown value forces the combined projection without changing matches.
        var combinedRequest = request with { Filters = filters with { Source = sources.Length == 0 ? [] : [.. sources, "another-unknown"] } };
        var actual = await service.GetTransactionsAsync(Cycle(), request, CancellationToken.None);
        var combined = await service.GetTransactionsAsync(Cycle(), combinedRequest, CancellationToken.None);
        actual.Should().BeEquivalentTo(combined, options => options.WithStrictOrdering());
        if (sources.Length > 0)
        {
            actual.Rows.Should().OnlyContain(row => sources.Contains(row.Source));
            if (!sources.Contains("AE") && !sources.Contains("UCP"))
            {
                actual.TotalCount.Should().Be(0);
            }
        }

        var summaryRequest = new ExpenseReviewSummaryRequest(includeState, includeZero, filters,
            byPeriod ? "accountingPeriod" : "source", 100, false);
        var summary = await service.GetSummaryAsync(Cycle(), summaryRequest, CancellationToken.None);
        summary.TotalCount.Should().Be(actual.TotalCount);
        summary.TotalAmount.Should().Be(actual.TotalAmount);
        var combinedSummary = await service.GetSummaryAsync(Cycle(), summaryRequest with { Filters = combinedRequest.Filters }, CancellationToken.None);
        summary.Should().BeEquivalentTo(combinedSummary, options => options.WithStrictOrdering());

        await using var actualCsv = new MemoryStream();
        await using var combinedCsv = new MemoryStream();
        await service.WriteTransactionsCsvAsync(Cycle(), request, actualCsv, CancellationToken.None);
        await service.WriteTransactionsCsvAsync(Cycle(), combinedRequest, combinedCsv, CancellationToken.None);
        actualCsv.ToArray().Should().Equal(combinedCsv.ToArray());

        foreach (var group in actual.Rows)
        {
            var detailRequest = new ExpenseReviewGroupTransactionsRequest(group.Id, request, "id", false, null);
            var combinedDetailRequest = detailRequest with { Context = combinedRequest };
            var detail = await service.GetGroupTransactionsAsync(Cycle(), detailRequest, CancellationToken.None);
            var combinedDetail = await service.GetGroupTransactionsAsync(Cycle(), combinedDetailRequest, CancellationToken.None);
            detail.Should().NotBeNull();
            detail!.Group.Should().BeEquivalentTo(group);
            detail.Rows.Should().NotBeEmpty();
            detail.MatchingAmount.Should().Be(group.Amount ?? 0m);
            var jsonOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
            JsonSerializer.Serialize(detail, jsonOptions).Should().Be(JsonSerializer.Serialize(combinedDetail, jsonOptions));

            await using var detailCsv = new MemoryStream();
            await using var combinedDetailCsv = new MemoryStream();
            await service.WriteGroupTransactionsCsvAsync(Cycle(), detailRequest, group, detailCsv, CancellationToken.None);
            await service.WriteGroupTransactionsCsvAsync(Cycle(), combinedDetailRequest, group, combinedDetailCsv, CancellationToken.None);
            detailCsv.ToArray().Should().Equal(combinedDetailCsv.ToArray());
        }

        var paged = new List<ExpenseReviewTransactionDto>();
        for (var page = 1; page <= Math.Max(1, actual.TotalCount); page++)
        {
            var result = await service.GetTransactionsAsync(Cycle(), request with { Page = page, PageSize = 1 }, CancellationToken.None);
            paged.AddRange(result.Rows);
        }
        paged.Should().BeEquivalentTo(actual.Rows, options => options.WithStrictOrdering());
    }

    [Theory]
    [InlineData("AE", "UCP")]
    [InlineData("UCP", "AE")]
    public async Task Alternating_source_requests_preserve_results(string first, string second)
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());
        var firstRequest = Request(filters: Filters(source: [first]));
        var original = await service.GetTransactionsAsync(Cycle(), firstRequest, CancellationToken.None);
        var other = await service.GetTransactionsAsync(Cycle(), Request(filters: Filters(source: [second])), CancellationToken.None);
        var repeated = await service.GetTransactionsAsync(Cycle(), firstRequest, CancellationToken.None);

        original.Rows.Should().NotBeEmpty().And.OnlyContain(row => row.Source == first);
        other.Rows.Should().NotBeEmpty().And.OnlyContain(row => row.Source == second);
        repeated.Should().BeEquivalentTo(original, options => options.WithStrictOrdering());
    }

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
        ucPathGroup.Entity.Name.Should().Be("Entity One");
        ucPathGroup.FinancialDept.Name.Should().Be("Dept One");
        ucPathGroup.Fund.Name.Should().Be("Fund One");
        ucPathGroup.Account.Name.Should().Be("Account One");
        ucPathGroup.AeProject.Name.Should().Be("Project One");
        ucPathGroup.Purpose.Name.Should().Be("Purpose One");
        ucPathGroup.Program.Name.Should().Be("Program One");
        ucPathGroup.Activity.Name.Should().Be("Activity One");

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

        var filters = await service.GetFilterOptionsAsync(cycle, ExpenseReviewFilters.None, CancellationToken.None);
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
    public async Task GetTransactionsAsync_total_amount_matches_the_filtered_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetTransactionsAsync(
            Cycle(),
            Request(includeState: ExpenseReviewIncludeState.Excluded, pageSize: 500),
            CancellationToken.None);

        response.TotalAmount.Should().Be(response.Rows.Sum(row => row.Amount ?? 0m));
        response.Rows.Should().NotBeEmpty();
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
    public async Task Transaction_queries_explain_missing_classifications_except_exempt_purpose()
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
        all.Rows.Should().Contain(row =>
            row.Purpose.Code == "P-MISSING" &&
            row.AeProject.Code == "PR-204" &&
            row.Included &&
            row.ExclusionReasons.Count == 0);
        all.Rows.Should().Contain(row =>
            row.Purpose.Code == "P-MISSING" &&
            row.Fund.Code == "F1" &&
            row.AeProject.Code == "PR1" &&
            !row.Included);
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

        var filters = await service.GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);
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
        // Ordered by summed FTE descending. Rows with no job code (the base
        // scenario's rows, JC-MISSING and JC-BLANK) are left out: there is no
        // code to classify.
        response.Rows.Select(row => (row.JobCode, row.Reason)).Should().Equal(
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

        // 4460 is only on a row outside the cycle window.
        response.Rows.Should().NotContain(row => row.JobCode == "4460");
    }

    [Fact]
    public async Task Unmatched_job_codes_skip_rows_excluded_from_the_report()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();
        await SeedUnmatchedJobCodeRowsExcludedFromReportAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetUnmatchedJobCodesAsync(Cycle(), CancellationToken.None);

        // 4444 is only on an excluded fund and 4445 only on an unclassified
        // department, so neither job code needs classifying.
        response.Rows.Should().NotContain(row => row.JobCode == "4444");
        response.Rows.Should().NotContain(row => row.JobCode == "4445");

        // 5678 has one included row and one on the excluded fund; only the
        // included row counts.
        var noStaffType = response.Rows.Single(row => row.JobCode == "5678");
        noStaffType.RowCount.Should().Be(1);
        noStaffType.Amount.Should().Be(10m);
        noStaffType.Fte.Should().Be(0.050000m);
    }

    [Fact]
    public async Task Unmatched_job_codes_keep_zero_fte_job_codes_with_state_appropriations_dollars()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();
        await SeedUnmatchedJobCodeRowsOnStateAppropriationsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetUnmatchedJobCodesAsync(Cycle(), CancellationToken.None);

        // Rule 220 only associates 13U02 payroll dollars on FTE line 241, so
        // classifying 4448 can move its $40 even though it reports no FTE.
        var stateFunded = response.Rows.Single(row => row.JobCode == "4448");
        stateFunded.Reason.Should().Be("noTitle");
        stateFunded.RowCount.Should().Be(1);
        stateFunded.Amount.Should().Be(40m);
        stateFunded.Fte.Should().Be(0m);

        // 4449's 13U02 dollars net to zero, so there is nothing to associate.
        response.Rows.Should().NotContain(row => row.JobCode == "4449");

        // 4448 totals zero FTE, so it sorts after every code with FTE.
        response.Rows[^1].JobCode.Should().Be("4448");
    }

    [Fact]
    public async Task Unmatched_job_codes_keep_job_codes_whose_dollars_or_fte_offset_across_summary_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();
        await SeedUnmatchedJobCodeRowsOnStateAppropriationsAsync();
        await SeedUnmatchedJobCodeRowsOffsettingAcrossSummaryRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetUnmatchedJobCodesAsync(Cycle(), CancellationToken.None);

        // 4450 has +$25 for one PI and -$25 for another on 13U02. The build
        // keeps one summary row per employee, so rule 220 would associate
        // each one even though the job code nets to zero.
        var offsettingDollars = response.Rows.Single(row => row.JobCode == "4450");
        offsettingDollars.RowCount.Should().Be(2);
        offsettingDollars.EmployeeCount.Should().Be(2);
        offsettingDollars.Amount.Should().Be(0m);
        offsettingDollars.Fte.Should().Be(0m);

        // 4451 has +0.5 FTE for one employee and -0.5 for another. Each
        // summary row carries its own FTE with no line.
        var offsettingFte = response.Rows.Single(row => row.JobCode == "4451");
        offsettingFte.RowCount.Should().Be(2);
        offsettingFte.Amount.Should().Be(80m);
        offsettingFte.Fte.Should().Be(0m);

        // 13U02 dollars for one PI that offset across each of the other
        // columns the build groups by: department, entity, project,
        // activity, employee name and fund.
        response.Rows.Select(row => row.JobCode).Should().Contain(["4454", "4455", "4456", "4457", "4458", "4459"]);

        // 4452's FTE cancels inside one summary row, so no row reports FTE.
        response.Rows.Should().NotContain(row => row.JobCode == "4452");

        // 4453 has FTE but its dollars net to zero, so the build drops the
        // summary row and its FTE with it.
        response.Rows.Should().NotContain(row => row.JobCode == "4453");
    }

    [Fact]
    public async Task Unmatched_job_codes_group_like_the_built_expense_summary()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();
        await SeedUnmatchedJobCodeRowsExcludedFromReportAsync();
        await SeedUnmatchedJobCodeRowsWithoutReportedFteAsync();
        await SeedUnmatchedJobCodeRowsOnStateAppropriationsAsync();
        await SeedUnmatchedJobCodeRowsOffsettingAcrossSummaryRowsAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        // BuildAutoAssociations needs an OrgR for every included row and a
        // project list. Both PIs behind 4450's offsetting dollars get a project.
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA'), ('BBBB');

            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR])
            VALUES ('D1', 'AAAA'), ('D2', 'BBBB');

            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [UcpEmployeeId])
            VALUES
                ('1000001', 'CA-D-ABC-1001-H', 0, '201', '30000013'),
                ('1000002', 'CA-D-ABC-1002-H', 0, '201', '30000014');
            """);

        var cycle = Cycle();
        var window = new { cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue), cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue) };
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);

        // The report regroups transactions itself, so this checks that its
        // grouping agrees with the summary the build really produced: the same
        // test (FTE, or on 13U02) applied to the built rows picks the same codes.
        var expected = (await connection.QueryAsync<string>(
            """
            SELECT DISTINCT [JobCode]
            FROM [data].[ExpenseSummary]
            WHERE [Source] = N'UCPath'
              AND [FteSfn] IS NULL
              AND NULLIF([JobCode], N'') IS NOT NULL
              AND ([Fte] <> 0 OR [Fund] = '13U02')
            """)).ToList();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        var response = await service.GetUnmatchedJobCodesAsync(cycle, CancellationToken.None);

        expected.Should().Contain(["0000", "4448", "4450", "4451", "4454", "4455", "4456", "4457", "4458", "4459"]);
        response.Rows.Select(row => row.JobCode).Should().BeEquivalentTo(expected);

        // Why 4450 has to be listed: nothing of it is associated yet, and
        // classifying it on FTE line 241 gives rule 220 a row for each PI.
        const string staged4450Sql =
            """
            SELECT s.[EmployeeId], a.[Expenses]
            FROM [data].[StagedAssociations] a
            JOIN [data].[ExpenseSummary] s ON s.[ExpenseId] = a.[ExpenseId]
            WHERE a.[Rule] = N'220' AND s.[JobCode] = '4450'
            """;
        (await connection.QueryAsync<(string EmployeeId, decimal Expenses)>(staged4450Sql)).Should().BeEmpty();

        await connection.ExecuteAsync(
            "INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name]) VALUES ('4450', 'PROF', 'Now classified');");
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);

        (await connection.QueryAsync<(string EmployeeId, decimal Expenses)>(staged4450Sql)).Should().BeEquivalentTo(new[]
        {
            ("30000013", 25m),
            ("30000014", -25m),
        });

        var afterClassifying = await service.GetUnmatchedJobCodesAsync(cycle, CancellationToken.None);
        afterClassifying.Rows.Should().NotContain(row => row.JobCode == "4450");
    }

    [Fact]
    public async Task Unmatched_job_codes_skip_job_codes_with_no_reported_fte()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedUnmatchedJobCodeRowsAsync();
        await SeedUnmatchedJobCodeRowsWithoutReportedFteAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var response = await service.GetUnmatchedJobCodesAsync(Cycle(), CancellationToken.None);

        // 4446 has dollars but zero FTE, and 4447's only FTE is on an excluded
        // ERN code, so classifying either would not change a reported FTE line.
        response.Rows.Should().NotContain(row => row.JobCode == "4446");
        response.Rows.Should().NotContain(row => row.JobCode == "4447");

        // 5678 gains a row on the excluded ERN code: its dollars count, its FTE does not.
        var noStaffType = response.Rows.Single(row => row.JobCode == "5678");
        noStaffType.RowCount.Should().Be(2);
        noStaffType.Amount.Should().Be(70m);
        noStaffType.Fte.Should().Be(0.050000m);
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

        var grantRow = all.Rows.Should().ContainSingle(row => row.Source == "UCP" && row.Account.Code == "531010" && row.Fund.Code == "F219").Subject;
        grantRow.Included.Should().BeTrue();
        grantRow.ExclusionReasons.Should().BeEmpty();

        var aeRow = all.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Account.Code == "531010").Subject;
        aeRow.Included.Should().BeTrue();

        var filters = await service.GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);
        filters.ExclusionReasons.Should().Contain(option =>
            option.Value == "account:531010" && option.Label == "UCPath account 531010 on a Hatch fund");
    }

    [Fact]
    public async Task Transaction_queries_exclude_204_rows_off_the_project_list_with_a_reason()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using (var connection = new SqlConnection(fixture.ConnectionString))
        {
            await connection.OpenAsync();
            await connection.ExecuteAsync(
                """
                INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
                VALUES ('Fund', 'F204', 'Grant fund', 1, '204');

                INSERT INTO [data].[AETransactions]
                    ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                     [EntityDescription], [FundDescription], [FinancialDepartmentDescription], [AccountDescription],
                     [PurposeDescription], [ProgramDescription], [ProjectDescription], [ActivityDescription],
                     [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
                VALUES
                    ('3310', 'F204', 'D1', 'A1', 'P1', 'PG1', 'PR-OFF-LIST', 'AC1',
                     'Entity One', 'Grant fund', 'Dept One', 'Account One', 'Purpose One', 'Program One', 'Off list', 'Activity One',
                     'Oct-24', 64.00, 0, 0);
                """);
        }

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        var offListRow = all.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Fund.Code == "F204").Subject;
        offListRow.Included.Should().BeFalse();
        offListRow.ExclusionReasons.Should().ContainSingle(reason =>
            reason.Code == "sfn:204NotOnProjectList" &&
            reason.Label == "SFN 204 project not on the project list" &&
            reason.RowCount == 1 &&
            reason.Amount == 64m);

        var filters = await service.GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);
        filters.ExclusionReasons.Should().Contain(option =>
            option.Value == "sfn:204NotOnProjectList" && option.Label == "SFN 204 project not on the project list");
    }

    private async Task SeedAccount531010RowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('Fund', 'F219', 'Grant fund', 1, '219'),
                ('Account', '531010', 'Academic salary', 1, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-531010-HATCH', '3310', 'F1',   'D1', 'D1', '531010', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000011', 'POS00011', 10.000000, 61.00, 0.050000, '2024-11-30', 'S', 2025, '5', 0, 0, 0, 0),
                ('UCP-531010-GRANT', '3310', 'F219', 'D1', 'D1', '531010', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
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
                ('JC-BLANK',          '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000005', 'POS5', '',     10, 10.00, 0.030000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STAFF-TYPE-MISSING', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000006', 'POS6', '7777', 10, 10.00, 0.020000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                -- Out of window with no flag set: the cycle window alone must drop it.
                ('JC-OUT-OF-WINDOW',  '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000025', 'POS25', '4460', 10, 10.00, 0.100000, '2023-11-15', 'S', 2024, '5', 0, 0, 0, 0),
                -- Flagged rows are in window but already excluded; they must not count.
                ('JC-NO-TITLE-DATE-FLAG',    '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 50.00, 0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 1, 0),
                ('JC-NO-TITLE-ACCOUNT-FLAG', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000002', 'POS2', '0000', 10, 60.00, 0.600000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 1);
            """);
    }

    // Unmatched job codes whose FTE is not reported: zero FTE, or FTE only on
    // an ERN code classified excluded (an excluded ERN drops FTE, never dollars).
    private async Task SeedUnmatchedJobCodeRowsWithoutReportedFteAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Ern', 'E09', 'Excluded Pay', 0, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-ZERO-FTE',               '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000009', 'POS9', '4446', 0,  40.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-EXCLUDED-ERN',           '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E09', '30000010', 'POS10', '4447', 10, 50.00, 0.400000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-NO-STAFF-TYPE-EXCLUDED-ERN', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E09', '30000003', 'POS3', '5678', 10, 60.00, 0.600000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);
    }

    // Unmatched job codes with no reported FTE on State Appropriations (13U02),
    // the fund rule 220 associates by FTE line.
    private async Task SeedUnmatchedJobCodeRowsOnStateAppropriationsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label])
            VALUES ('220', 'State Appropriations');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Fund', '13U02', 'State Appropriations', 1, '220');

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-STATE-ZERO-FTE',     '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000011', 'POS11', '4448', 0,  40.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-NET-ZERO-A',   '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000012', 'POS12', '4449', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-NET-ZERO-B',   '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000012', 'POS12', '4449', 0, -25.00, 0.000000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0);
            """);
    }

    // Unmatched job codes whose dollars or FTE net to zero across the job code
    // but not inside each expense summary row. BuildAutoAssociations keeps one
    // row per employee and chart string. Needs the 13U02 fund from
    // SeedUnmatchedJobCodeRowsOnStateAppropriationsAsync.
    private async Task SeedUnmatchedJobCodeRowsOffsettingAcrossSummaryRowsAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D2', 'Dept Two', 1, NULL),
                ('Activity', 'AC2', 'Activity Two', 1, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                -- 13U02 dollars that offset across two PIs.
                ('JC-STATE-OFFSET-PI-A',  '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000013', 'POS13', '4450', 0,   25.00,  0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-PI-B',  '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000014', 'POS14', '4450', 0,  -25.00,  0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                -- FTE that offsets across two employees.
                ('JC-FTE-OFFSET-EMP-A',   '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000015', 'POS15', '4451', 10,  50.00,  0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-FTE-OFFSET-EMP-B',   '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000016', 'POS16', '4451', 10,  30.00, -0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                -- FTE that offsets inside one summary row.
                ('JC-FTE-OFFSET-SAME-A',  '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000017', 'POS17', '4452', 10,  50.00,  0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-FTE-OFFSET-SAME-B',  '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000017', 'POS17', '4452', 10,  30.00, -0.500000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0),
                -- FTE on a summary row whose dollars net to zero.
                ('JC-FTE-NO-DOLLARS-A',   '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000018', 'POS18', '4453', 10,  50.00,  0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-FTE-NO-DOLLARS-B',   '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000018', 'POS18', '4453', 0,  -50.00,  0.000000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0),
                -- 13U02 dollars for one PI that offset across two departments.
                ('JC-STATE-OFFSET-DEPT-A', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000019', 'POS19', '4454', 0,   25.00,  0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-DEPT-B', '3310', '13U02', 'D2', 'D2', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000019', 'POS19', '4454', 0,  -25.00,  0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);

            -- 13U02 dollars for one PI that offset across each remaining column
            -- the build groups by: entity, project, activity, employee name, fund.
            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-STATE-OFFSET-ENTITY-A',   '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000020', NULL,          'POS20', '4455', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-ENTITY-B',   '3320', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000020', NULL,          'POS20', '4455', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-PROJECT-A',  '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000021', NULL,          'POS21', '4456', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-PROJECT-B',  '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR2', 'AC1', 'E01', '30000021', NULL,          'POS21', '4456', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-ACTIVITY-A', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000022', NULL,          'POS22', '4457', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-ACTIVITY-B', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC2', 'E01', '30000022', NULL,          'POS22', '4457', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-NAME-A',     '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000023', 'Name, Old',   'POS23', '4458', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-NAME-B',     '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000023', 'Name, New',   'POS23', '4458', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-FUND-A',     '3310', '13U02', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000024', NULL,          'POS24', '4459', 0,  25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-STATE-OFFSET-FUND-B',     '3310', 'F1',    'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000024', NULL,          'POS24', '4459', 0, -25.00, 0.000000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);
    }

    // Unmatched job codes on rows the report drops: fund F2 is classified
    // excluded and department D-UNCLASSIFIED has no classification (fails closed).
    private async Task SeedUnmatchedJobCodeRowsExcludedFromReportAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name])
            VALUES ('4444', NULL, 'Title only on excluded rows');

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JC-EXCLUDED-FUND',               '3310', 'F2', 'D1',             'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000007', 'POS7', '4444', 10, 70.00, 0.700000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-NO-STAFF-TYPE-EXCLUDED-FUND', '3310', 'F2', 'D1',             'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000003', 'POS3', '5678', 10, 80.00, 0.800000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('JC-UNCLASSIFIED-DEPT',           '3310', 'F1', 'D-UNCLASSIFIED', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01', '30000008', 'POS8', '4445', 10, 90.00, 0.900000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
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

    [Fact]
    public async Task GetFilterOptionsAsync_limits_each_dropdown_to_values_matching_the_other_filters()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedSecondDeptRowAsync();
        var cache = new ExpenseReviewFilterCache();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration(), cache);

        var byDept = await service.GetFilterOptionsAsync(
            Cycle(), Filters(financialDept: ["D1"]), CancellationToken.None);
        var bySecondDept = await service.GetFilterOptionsAsync(
            Cycle(), Filters(financialDept: ["D2"]), CancellationToken.None);
        var byReason = await service.GetFilterOptionsAsync(
            Cycle(), Filters(exclusionReason: ["fund:excluded"]), CancellationToken.None);

        byDept.Funds.Select(option => option.Value).Should().Equal("F1", "F2");
        byDept.FinancialDepts.Select(option => option.Value).Should().Equal("D1", "D2");
        byDept.Sources.Select(option => option.Value).Should().Equal("AE", "UCP");
        bySecondDept.Funds.Should().ContainSingle()
            .Which.Should().Be(new ExpenseReviewFilterOptionDto("F3", "F3 - Fund Three"));
        bySecondDept.Sources.Select(option => option.Value).Should().Equal("AE");
        byReason.Funds.Select(option => option.Value).Should().Equal("F2");
    }

    [Fact]
    public async Task Filter_facts_preserve_reasonless_and_multi_reason_combinations_and_cached_narrowing()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMultiReasonTransactionAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        using var reader = await connection.QueryMultipleAsync(ExpenseReviewService.FilterIndexSql,
            new { cycleStart = Cycle().CycleStart.ToDateTime(TimeOnly.MinValue), cycleEnd = Cycle().CycleEnd.ToDateTime(TimeOnly.MinValue) });
        await reader.ReadAsync();
        var combos = (await reader.ReadAsync<ExpenseReviewFilterCombo>()).ToList();
        combos.Select(combo => (combo.Source, combo.AeProjectCode, combo.AccountingPeriod, combo.ExclusionReasonMask))
            .Should().BeEquivalentTo(new (string?, string?, string?, int)[]
            {
                ("AE", "PR1", "Oct-24", 0),
                ("AE", "PR1", "Nov-24", 0),
                ("UCP", "PR1", "Nov-24", 0),
                ("AE", "PR1", "Oct-24", ExpenseReviewExclusionReasons.BitForCode("fund:excluded")),
                ("AE", "PR-MULTI", "Oct-24", ExpenseReviewExclusionReasons.BitForCode("excludedByDate") | ExpenseReviewExclusionReasons.BitForCode("aeAccountInUcPath")),
            });

        var cache = new ExpenseReviewFilterCache();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration(), cache);
        var options = await service.GetFilterOptionsAsync(Cycle(), Filters(), CancellationToken.None);
        options.AccountingPeriods.Select(option => option.Value).Should().Equal("Oct-24", "Nov-24");
        options.ExclusionReasons.Select(option => option.Label).Should().Equal(
            "AE account also in UCPath", "Excluded by date", "Excluded by fund");
        var narrowed = await service.GetFilterOptionsAsync(Cycle(),
            Filters(aeProject: ["PR-MULTI"], exclusionReason: ["excludedByDate"]), CancellationToken.None);
        narrowed.ExclusionReasons.Select(option => option.Value).Should().Equal("aeAccountInUcPath", "excludedByDate");
        narrowed.AeProjects.Select(option => option.Value).Should().Equal("PR-MULTI");
        narrowed.Funds.Select(option => option.Value).Should().Equal("F1");
    }

    private async Task SeedSecondDeptRowAsync()
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
                ('3310', 'F3', 'D2', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                 'Entity One', 'Fund Three', 'Dept Two', 'Account One', 'Purpose One', 'Program One', 'Project One', 'Activity One',
                 'Oct-24', 40.00, 0, 0);
            """);
    }

    [Fact]
    public async Task GetFilterOptionsAsync_with_a_cache_reuses_the_first_load_for_the_cycle()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        var cache = new ExpenseReviewFilterCache();

        ExpenseReviewFilterOptionsResponse first;
        await using (var firstDb = fixture.CreateDataDbContext())
        {
            first = await new ExpenseReviewService(firstDb, Configuration(), cache)
                .GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);
        }

        await fixture.ClearDataTablesAsync();

        await using var secondDb = fixture.CreateDataDbContext();
        var cached = await new ExpenseReviewService(secondDb, Configuration(), cache)
            .GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);
        var uncached = await new ExpenseReviewService(secondDb, Configuration())
            .GetFilterOptionsAsync(Cycle(), ExpenseReviewFilters.None, CancellationToken.None);

        first.Funds.Should().NotBeEmpty();
        cached.Should().BeSameAs(first);
        uncached.Funds.Should().BeEmpty();
    }

    [Fact]
    public async Task GetSummaryAsync_by_fund_matches_sums_of_the_grouped_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());

        var rows = await service.GetTransactionsAsync(Cycle(), Request(pageSize: 500), CancellationToken.None);
        var summary = await service.GetSummaryAsync(
            Cycle(),
            new ExpenseReviewSummaryRequest(ExpenseReviewIncludeState.All, false, Filters(), "fund", 100, false),
            CancellationToken.None);

        var expected = rows.Rows
            .GroupBy(row => row.Fund.Code)
            .Select(group => new { Code = group.Key, RowCount = group.Count(), Amount = group.Sum(row => row.Amount ?? 0m) })
            .ToList();

        summary.TotalCount.Should().Be(rows.TotalCount);
        summary.TotalAmount.Should().Be(rows.TotalAmount);
        summary.GroupCount.Should().Be(expected.Count);
        summary.Groups.Select(group => (group.Code, group.RowCount, group.Amount))
            .Should().BeEquivalentTo(expected.Select(item => (item.Code, item.RowCount, item.Amount)));
        summary.Groups.Should().BeInDescendingOrder(group => group.Amount);
    }

    [Fact]
    public async Task GetSummaryAsync_limit_truncates_groups_but_reports_the_full_count()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());

        var full = await service.GetSummaryAsync(
            Cycle(),
            new ExpenseReviewSummaryRequest(ExpenseReviewIncludeState.All, false, Filters(), "fund", 100, false),
            CancellationToken.None);
        var limited = await service.GetSummaryAsync(
            Cycle(),
            new ExpenseReviewSummaryRequest(ExpenseReviewIncludeState.All, false, Filters(), "fund", 1, false),
            CancellationToken.None);

        full.GroupCount.Should().BeGreaterThan(1);
        limited.Groups.Should().HaveCount(1);
        limited.GroupCount.Should().Be(full.GroupCount);
        limited.Groups[0].Should().BeEquivalentTo(full.Groups[0]);
    }

    [Fact]
    public async Task GetSummaryAsync_by_exclusion_reason_matches_the_row_reason_chips()
    {
        await fixture.ClearDataTablesAsync();
        await SeedMultiReasonTransactionAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());

        var rows = await service.GetTransactionsAsync(
            Cycle(),
            Request(includeState: ExpenseReviewIncludeState.Excluded, pageSize: 500),
            CancellationToken.None);
        var summary = await service.GetSummaryAsync(
            Cycle(),
            new ExpenseReviewSummaryRequest(ExpenseReviewIncludeState.Excluded, false, Filters(), "exclusionReason", 100, false),
            CancellationToken.None);

        var expected = rows.Rows
            .SelectMany(row => row.ExclusionReasons)
            .GroupBy(reason => reason.Code)
            .Select(group => (Code: group.Key, RowCount: group.Sum(r => r.RowCount), Amount: group.Sum(r => r.Amount)))
            .ToList();

        summary.Groups.Select(group => (group.Code, group.RowCount, group.Amount))
            .Should().BeEquivalentTo(expected);
        summary.GroupCount.Should().Be(expected.Count);
    }

    [Theory]
    [InlineData("AE", false)]
    [InlineData("AE", true)]
    [InlineData("UCP", false)]
    [InlineData("UCP", true)]
    public async Task Group_details_preserve_membership_totals_and_parent_filters(string source, bool byPeriod)
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();
        await SeedMultiReasonTransactionAsync();
        await SeedZeroAmountGroupAsync();
        await SeedNullAmountTransactionAsync();
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());
        foreach (var filters in new[] { Filters(source: [source]), Filters(source: [source], accountingPeriod: ["Nov-24"]),
                     Filters(source: [source], exclusionReason: [source == "AE" ? "excludedByDate" : "ucPathAccountNotInAE"]) })
        {
            var context = Request(displayByPeriod: byPeriod, includeZeroAmounts: true, filters: filters);
            var groups = await service.GetTransactionsAsync(Cycle(), context, CancellationToken.None);
            foreach (var group in groups.Rows)
            {
                var request = new ExpenseReviewGroupTransactionsRequest(group.Id, context, "transactionDate", false, null);
                var detail = (await service.GetGroupTransactionsAsync(Cycle(), request, CancellationToken.None))!;
                detail.Should().NotBeNull();
                detail.Group.Should().BeEquivalentTo(group);
                detail.Rows.Should().HaveCount(detail.TransactionCount);
                detail.MatchingCount.Should().Be(detail.TransactionCount);
                detail.Rows.Sum(row => row.Amount ?? 0m).Should().Be(group.Amount ?? 0m);
                detail.MatchingAmount.Should().Be(group.Amount ?? 0m);
                foreach (var reason in group.ExclusionReasons)
                {
                    var membersWithReason = detail.Rows.Where(row => row.ExclusionReasons.Any(r => r.Code == reason.Code)).ToArray();
                    membersWithReason.Should().HaveCount(reason.RowCount);
                    membersWithReason.Sum(row => row.Amount ?? 0m).Should().Be(reason.Amount);
                    var reasonSearch = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = reason.Label }, CancellationToken.None))!;
                    reasonSearch.MatchingCount.Should().Be(reason.RowCount);
                }
                if (group.Amount == 0m)
                {
                    var hidden = request with { Context = context with { IncludeZeroAmounts = false } };
                    (await service.GetGroupTransactionsAsync(Cycle(), hidden, CancellationToken.None)).Should().BeNull();
                }
                if (byPeriod) detail.Rows.Should().OnlyContain(row => row.AccountingPeriod == group.AccountingPeriod);
                if (filters.AccountingPeriod.Count > 0) detail.Rows.Should().OnlyContain(row => row.AccountingPeriod == "Nov-24");
                if (filters.ExclusionReason.Count > 0) detail.Rows.Should().OnlyContain(row => row.ExclusionReasons.Any(reason => reason.Code == filters.ExclusionReason[0]));
                var empty = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = "no-such-transaction" }, CancellationToken.None))!;
                empty.TransactionCount.Should().Be(detail.TransactionCount);
                empty.Group.Should().BeEquivalentTo(group);
                empty.Rows.Should().BeEmpty();
                empty.MatchingCount.Should().Be(0);
            }
        }
    }

    [Fact]
    public async Task Details_search_sort_pagination_and_export_preserve_precision_and_all_matching_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync("""
            UPDATE [data].[AETransactions] SET [JournalAcctDate] = '2024-10-15',
                [AccountingSequenceNumber] = CASE WHEN [PeriodName] = 'Oct-24' THEN 10 ELSE 2 END,
                [JournalName] = N'Journal, "quoted"', [JournalReference] = N'Hidden reference',
                [JournalLineDescription] = N'Line' + CHAR(13) + CHAR(10) + N'two'
            WHERE [Fund] = 'F1';
            INSERT INTO [data].[AETransactions]
                ([Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath], [JournalAcctDate], [AccountingSequenceNumber], [JournalReference])
            SELECT TOP (30) '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                'Oct-24', 0, 0, 0, '2024-10-15', 9007199254740993, N'Hidden reference'
            FROM sys.all_objects;
            UPDATE TOP (1) [data].[AETransactions] SET [Amount] = -1.2345 WHERE [Amount] = 0;
            UPDATE TOP (1) [data].[AETransactions] SET [Amount] = NULL WHERE [Amount] = 0;
            UPDATE [data].[UcPathTransactions] SET [EmployeeName] = 'Ada Lovelace', [ErnDescription] = 'Regular earnings',
                [Hours] = 12.345678, [CalculatedFte] = 0.123456 WHERE [LaborTransactionId] = 'UCP-INCLUDED';
            """);
        var service = new ExpenseReviewService(fixture.CreateDataDbContext(), Configuration());
        var context = Request(filters: Filters(source: ["AE"], fund: ["F1"]), pageSize: 10);
        var group = (await service.GetTransactionsAsync(Cycle(), context, CancellationToken.None)).Rows.Single();
        var request = new ExpenseReviewGroupTransactionsRequest(group.Id, context, "accountingSequenceNumber", false, null);
        var first = (await service.GetGroupTransactionsAsync(Cycle(), request, CancellationToken.None))!;
        first.TransactionCount.Should().Be(32);
        first.MatchingAmount.Should().Be(123.7655m);
        first.Rows.Take(2).Select(row => row.AccountingSequenceNumber).Should().Equal("2", "10");
        first.Rows.Skip(2).Should().OnlyContain(row => row.AccountingSequenceNumber == "9007199254740993");
        var next = (await service.GetGroupTransactionsAsync(Cycle(), request with { Context = context with { Page = 2 } }, CancellationToken.None))!;
        first.Rows.Select(row => row.Id).Intersect(next.Rows.Select(row => row.Id)).Should().BeEmpty();
        var stable = (await service.GetGroupTransactionsAsync(Cycle(), request, CancellationToken.None))!;
        stable.Rows.Select(row => row.Id).Should().Equal(first.Rows.Select(row => row.Id));
        var searched = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = "HIDDEN REFERENCE" }, CancellationToken.None))!;
        searched.MatchingCount.Should().Be(32);
        var literal = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = "%" }, CancellationToken.None))!;
        literal.MatchingCount.Should().Be(0);
        await using var output = new MemoryStream();
        await service.WriteGroupTransactionsCsvAsync(Cycle(), request with { Search = "hidden reference" }, group, output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), System.Globalization.CultureInfo.InvariantCulture);
        await csv.ReadAsync(); csv.ReadHeader();
        csv.HeaderRecord.Should().Contain(["Document type", "Journal reference", "Transaction ID", "Fiscal Year", "Include State"]);
        var count = 0;
        while (await csv.ReadAsync())
        {
            count++;
            if (count == 1) csv.GetField("Accounting sequence number").Should().Be("2");
            if (count == 2) csv.GetField("Accounting sequence number").Should().Be("10");
            csv.GetField("Journal reference").Should().Be("Hidden reference");
            if (csv.GetField("Accounting sequence number") == "10")
            {
                csv.GetField("Journal name").Should().Be("Journal, \"quoted\"");
                csv.GetField("Line description").Should().Be("Line\r\ntwo");
            }
        }
        count.Should().Be(32);
        await connection.ExecuteAsync("""
            SET IDENTITY_INSERT [data].[AETransactions] ON;
            INSERT INTO [data].[AETransactions]
                ([Id], [Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath], [JournalAcctDate], [AccountingSequenceNumber], [JournalReference])
            VALUES (9007199254740993, '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                'Oct-24', 0, 0, 0, '2024-10-15', 9223372036854775806, N'Unique beyond page one');
            SET IDENTITY_INSERT [data].[AETransactions] OFF;
            """);
        var beyond = (await service.GetGroupTransactionsAsync(Cycle(), request with { Search = "unique BEYOND page one" }, CancellationToken.None))!;
        beyond.TransactionCount.Should().Be(33);
        beyond.MatchingCount.Should().Be(1);
        beyond.Rows.Single().Id.Should().Be("9007199254740993");
        beyond.Rows.Single().AccountingSequenceNumber.Should().Be("9223372036854775806");
        var payrollContext = Request(filters: Filters(source: ["UCP"]));
        var payrollGroup = (await service.GetTransactionsAsync(Cycle(), payrollContext, CancellationToken.None)).Rows.Single();
        var payrollRequest = new ExpenseReviewGroupTransactionsRequest(payrollGroup.Id, payrollContext, "transactionDate", false, "regular EARNINGS");
        var payroll = (await service.GetGroupTransactionsAsync(Cycle(), payrollRequest, CancellationToken.None))!;
        payroll.TransactionCount.Should().Be(2);
        payroll.MatchingCount.Should().Be(1);
        payroll.Rows.Single().EmployeeName.Should().Be("Ada Lovelace");
        payroll.Rows.Single().Hours.Should().Be(12.345678m);
        await using var payrollOutput = new MemoryStream();
        await service.WriteGroupTransactionsCsvAsync(Cycle(), payrollRequest, payrollGroup, payrollOutput, CancellationToken.None);
        var payrollCsv = Encoding.UTF8.GetString(payrollOutput.ToArray());
        payrollCsv.Should().Contain("12.345678").And.Contain("0.123456").And.Contain("Labor transaction ID").And.NotContain("EmployeeId");
        var wrongContext = request with { Context = context with { IncludeState = ExpenseReviewIncludeState.Excluded } };
        (await service.GetGroupTransactionsAsync(Cycle(), wrongContext, CancellationToken.None)).Should().BeNull();
    }

    [Theory]
    [InlineData("AE", "id", false)]
    [InlineData("AE", "ID", true)]
    [InlineData("UCP", "Id", false)]
    [InlineData("UCP", "iD", true)]
    public async Task Detail_id_sorting_preserves_native_order_exact_ids_and_joined_fields_across_pages_and_csv(
        string source, string sortBy, bool descending)
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        // Replace the baseline transactions, retaining its classifications and chart descriptions.
        await connection.ExecuteAsync("DELETE FROM [data].[AETransactions]; DELETE FROM [data].[UcPathTransactions];");
        long[] aeIds = [2, 10, 100, 9007199254740992, 9007199254740993, 10000000000000000];
        await connection.ExecuteAsync("SET IDENTITY_INSERT [data].[AETransactions] ON;");
        try
        {
            await connection.ExecuteAsync("""
                INSERT INTO [data].[AETransactions]
                    ([Id], [Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                     [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath], [JournalAcctDate], [JournalReference])
                VALUES (@Id, '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1',
                    'Oct-24', 1, 0, 0, '2024-10-15', @Reference);
                """, aeIds.Select(id => new { Id = id, Reference = $"Journal {id}" }));
        }
        finally
        {
            await connection.ExecuteAsync("SET IDENTITY_INSERT [data].[AETransactions] OFF;");
        }
        string[] laborIds = [
            "JRN24|0|0|20000001|0|E01|RUN-2", "JRN24|0|0|20000001|0|E01|RUN-10",
            "JRN24|0|0|20000001|0|E01|RUN-100", "JRN24|0|0|20000001|0|E01|RUN-A",
            "JRN24|0|0|20000001|0|E01|RUN-AA", "JRN24|0|0|20000001|0|E01|RUN-Z",
        ];
        await connection.ExecuteAsync("""
            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES (@Id, '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                '20000001', @EmployeeName, 'POS00001', 1, 1, 0.5, '2024-10-15', 'S', 2025, '4', 0, 0, 0, 0);
            """, laborIds.Select(id => new { Id = id, EmployeeName = $"Employee {id}" }));

        string[] ascendingIds = source == "AE"
            ? aeIds.Select(id => id.ToString(System.Globalization.CultureInfo.InvariantCulture)).ToArray()
            : [laborIds[1], laborIds[2], laborIds[0], laborIds[3], laborIds[4], laborIds[5]];
        var expectedIds = descending ? ascendingIds.Reverse().ToArray() : ascendingIds;
        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        var context = Request(filters: Filters(source: [source]), pageSize: 2);
        var group = (await service.GetTransactionsAsync(Cycle(), context, CancellationToken.None)).Rows.Single();
        var request = new ExpenseReviewGroupTransactionsRequest(group.Id, context, sortBy, descending, null);
        List<string> pagedIds = [];
        for (var page = 1; page <= 3; page++)
        {
            var response = (await service.GetGroupTransactionsAsync(Cycle(),
                request with { Context = context with { Page = page } }, CancellationToken.None))!;
            response.TransactionCount.Should().Be(expectedIds.Length);
            response.MatchingCount.Should().Be(expectedIds.Length);
            response.MatchingAmount.Should().Be(6m);
            response.PageCount.Should().Be(3);
            response.Rows.Select(row => row.Id).Should().Equal(expectedIds.Skip((page - 1) * 2).Take(2));
            foreach (var row in response.Rows)
            {
                row.TransactionDate.Should().Be(new DateTime(2024, 10, 15));
                if (source == "AE")
                {
                    row.JournalReference.Should().Be($"Journal {row.Id}");
                    row.EmployeeName.Should().BeNull();
                }
                else
                {
                    row.EmployeeName.Should().Be($"Employee {row.Id}");
                    row.JournalReference.Should().BeNull();
                }
            }
            var json = JsonSerializer.SerializeToElement(response, new JsonSerializerOptions(JsonSerializerDefaults.Web));
            foreach (var (row, expectedId) in json.GetProperty("rows").EnumerateArray().Zip(response.Rows.Select(row => row.Id)))
            {
                row.GetProperty("id").ValueKind.Should().Be(JsonValueKind.String);
                row.GetProperty("id").GetString().Should().Be(expectedId);
                row.EnumerateObject().Select(property => property.Name)
                    .Should().NotContain(["aeTransactionId", "laborTransactionId"]);
            }
            pagedIds.AddRange(response.Rows.Select(row => row.Id));
        }
        pagedIds.Should().Equal(expectedIds).And.OnlyHaveUniqueItems();
        var pastEnd = await service.GetGroupTransactionsAsync(Cycle(),
            request with { Context = context with { Page = 4 } }, CancellationToken.None);
        pastEnd!.Rows.Should().BeEmpty();

        await using var output = new MemoryStream();
        // Export must ignore pagination even when requested from a later page.
        await service.WriteGroupTransactionsCsvAsync(Cycle(), request with { Context = context with { Page = 2 } },
            group, output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), System.Globalization.CultureInfo.InvariantCulture);
        await csv.ReadAsync();
        csv.ReadHeader();
        csv.HeaderRecord.Should().NotContain(["AeTransactionId", "LaborTransactionId"]);
        List<string> csvIds = [];
        while (await csv.ReadAsync())
        {
            var id = csv.GetField(source == "AE" ? "Transaction ID" : "Labor transaction ID")!;
            csvIds.Add(id);
            csv.GetField(source == "AE" ? "Journal reference" : "Employee name")
                .Should().Be(source == "AE" ? $"Journal {id}" : $"Employee {id}");
        }
        csvIds.Should().Equal(pagedIds);
    }

    [Theory]
    [InlineData("AE", "AE")]
    [InlineData("AE", ":")]
    [InlineData("UCP", "UCP")]
    [InlineData("UCP", "CP")]
    [InlineData("UCP", ":")]
    public async Task Detail_id_search_ignores_internal_prefixes(string source, string search)
    {
        await SeedDetailIdSearchScenarioAsync();
        await AssertDetailIdSearchAsync(source, search, [], 0m);
    }

    [Theory]
    [InlineData("AE", "9007199254740993")]
    [InlineData("AE", "925474099")]
    [InlineData("UCP", "JRN24|RUN-2")]
    [InlineData("UCP", "run-2")]
    public async Task Detail_id_search_matches_full_and_partial_native_ids(string source, string search)
    {
        await SeedDetailIdSearchScenarioAsync();
        var expectedId = source == "AE" ? "9007199254740993" : "JRN24|RUN-2";
        await AssertDetailIdSearchAsync(source, search, [expectedId], source == "AE" ? 30m : 10m);
    }

    [Theory]
    [InlineData("AE", "ae")]
    [InlineData("AE", ":")]
    [InlineData("UCP", "ucp")]
    [InlineData("UCP", "cp")]
    [InlineData("UCP", ":")]
    public async Task Detail_id_search_preserves_prefix_text_in_native_ids_and_other_fields(string source, string search)
    {
        await SeedDetailIdSearchScenarioAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.ExecuteAsync("""
            UPDATE [data].[AETransactions] SET [JournalReference] = N'AE:reference' WHERE [Id] = 2;
            UPDATE [data].[UcPathTransactions] SET [LaborTransactionId] = N'UCP:RUN-2'
            WHERE [LaborTransactionId] = N'JRN24|RUN-2';
            """);
        await AssertDetailIdSearchAsync(source, search, [source == "AE" ? "2" : "UCP:RUN-2"], 10m);
    }

    [Fact]
    public async Task Detail_id_search_exports_all_native_id_matches_beyond_the_first_page()
    {
        await SeedDetailIdSearchScenarioAsync();
        await AssertDetailIdSearchAsync("UCP", "run-", ["JRN24|RUN-10", "JRN24|RUN-100", "JRN24|RUN-2"], 60m);
    }

    private async Task AssertDetailIdSearchAsync(string source, string search, string[] expectedIds, decimal expectedAmount)
    {
        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        var context = Request(filters: Filters(source: [source]), pageSize: 2);
        var group = (await service.GetTransactionsAsync(Cycle(), context, CancellationToken.None)).Rows.Single();
        var request = new ExpenseReviewGroupTransactionsRequest(group.Id, context, "id", false, search);
        var response = (await service.GetGroupTransactionsAsync(Cycle(), request, CancellationToken.None))!;
        response.TransactionCount.Should().Be(3);
        response.Group.Should().BeEquivalentTo(group);
        response.Group.Amount.Should().Be(60m);
        response.MatchingCount.Should().Be(expectedIds.Length);
        response.MatchingAmount.Should().Be(expectedAmount);
        response.PageCount.Should().Be((int)Math.Ceiling(expectedIds.Length / 2d));
        response.Rows.Select(row => row.Id).Should().Equal(expectedIds.Take(2));

        await using var output = new MemoryStream();
        await service.WriteGroupTransactionsCsvAsync(Cycle(), request, group, output, CancellationToken.None);
        output.Position = 0;
        using var csv = new CsvHelper.CsvReader(new StreamReader(output), System.Globalization.CultureInfo.InvariantCulture);
        (await csv.ReadAsync()).Should().BeTrue();
        csv.ReadHeader();
        var idColumn = source == "AE" ? "Transaction ID" : "Labor transaction ID";
        csv.HeaderRecord.Should().Contain(idColumn);
        List<string> csvIds = [];
        decimal csvAmount = 0m;
        while (await csv.ReadAsync())
        {
            csvIds.Add(csv.GetField(idColumn)!);
            csvAmount += csv.GetField<decimal>("Amount");
        }
        csvIds.Should().Equal(expectedIds);
        csvAmount.Should().Be(expectedAmount);
    }

    private async Task SeedDetailIdSearchScenarioAsync()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        // Retain classifications while keeping native IDs out of every other searchable field.
        await connection.ExecuteAsync("DELETE FROM [data].[AETransactions]; DELETE FROM [data].[UcPathTransactions];");
        await connection.ExecuteAsync("SET IDENTITY_INSERT [data].[AETransactions] ON;");
        try
        {
            await connection.ExecuteAsync("""
                INSERT INTO [data].[AETransactions]
                    ([Id], [Entity], [Fund], [FinancialDepartment], [Account], [Purpose], [Program], [Project], [Activity],
                     [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
                VALUES
                    (2, '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'Oct-24', 10, 0, 0),
                    (10, '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'Oct-24', 20, 0, 0),
                    (9007199254740993, '3310', 'F1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'Oct-24', 30, 0, 0);
                """);
        }
        finally
        {
            await connection.ExecuteAsync("SET IDENTITY_INSERT [data].[AETransactions] OFF;");
        }
        await connection.ExecuteAsync("""
            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('JRN24|RUN-2', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000001', 'POS00001', 1, 10, 0.5, '2024-10-15', 'S', 2025, '4', 0, 0, 0, 0),
                ('JRN24|RUN-10', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000001', 'POS00001', 1, 20, 0.5, '2024-10-15', 'S', 2025, '4', 0, 0, 0, 0),
                ('JRN24|RUN-100', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000001', 'POS00001', 1, 30, 0.5, '2024-10-15', 'S', 2025, '4', 0, 0, 0, 0);
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
                ('Entity', '3310', 'Entity One', '3310 - Entity One'),
                ('FinancialDepartment', 'D1', 'Dept One', 'D1 - Dept One'),
                ('Fund', 'F1', 'Fund One', 'F1 - Fund One'),
                ('Fund', 'F2', 'Fund Two', 'F2 - Fund Two'),
                ('Account', 'A1', 'Account One', 'A1 - Account One'),
                ('Project', 'PR1', 'Project One', 'PR1 - Project One'),
                ('Purpose', 'P1', 'Purpose One', 'P1 - Purpose One'),
                ('Program', 'PG1', 'Program One', 'PG1 - Program One'),
                ('Activity', 'AC1', 'Activity One', 'AC1 - Activity One');

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
            VALUES ('Fund', 'F0', 'Zero Fund', 'F0 - Zero Fund');

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

            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES ('1000204', 'CA-D-XYZ-0001-CG', 1, '204', 'PR-204');

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
                 'Oct-24', 515.00, 0, 0),
                ('3310', 'F1', 'D1', 'A1', 'P-MISSING', 'PG1', 'PR-204', 'AC1',
                 'Entity One', 'Fund One', 'Dept One', 'Account One', 'Missing Purpose', 'Program One', 'Missing Purpose 204 Project', 'Activity One',
                 'Oct-24', 516.00, 0, 0);
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
