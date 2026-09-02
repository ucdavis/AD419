using System.Text;
using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;
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
        var service = CreateService(db);
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
            reason.Code == "fund:F2:excluded" &&
            reason.Label == "Fund F2 excluded" &&
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
            Request(filters: Filters(exclusionReason: ["fund:F2:excluded"])),
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
            option.Value == "fund:F2:excluded" && option.Label == "Fund F2 excluded");
    }

    [Fact]
    public async Task Missing_cache_is_lazily_rebuilt_before_expense_review_reads()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = CreateService(db);

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.TotalCount.Should().Be(3);
        await using var connection = new SqlConnection(fixture.ConnectionString);
        var status = await connection.QuerySingleAsync<(int FactRowCount, int ReasonRowCount)>(
            """
            SELECT [FactRowCount], [ReasonRowCount]
            FROM [data].[ExpenseReviewCacheStatus]
            WHERE [CycleStart] = @cycleStart
              AND [CycleEnd] = @cycleEnd;
            """,
            new
            {
                cycleStart = Cycle().CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = Cycle().CycleEnd.ToDateTime(TimeOnly.MinValue),
            });
        status.FactRowCount.Should().Be(5);
        status.ReasonRowCount.Should().Be(1);
    }

    [Fact]
    public async Task Transaction_queries_explain_persisted_exclusion_flags()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = CreateService(db);

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
            reason.Label == "Date excluded" &&
            reason.RowCount == 1 &&
            reason.Amount == 401m);
        aeExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "aeAccountInUcPath:A1" &&
            reason.Label == "AE account A1 also in UCPath" &&
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
            reason.Label == "Date excluded" &&
            reason.RowCount == 1 &&
            reason.Amount == 403m);
        ucPathExcludedGroup.ExclusionReasons.Should().Contain(reason =>
            reason.Code == "ucPathAccountNotInAE:A1" &&
            reason.Label == "UCPath account A1 missing from AE chart" &&
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
    public async Task Transaction_queries_explain_missing_classifications_except_13u02_purpose()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMissingClassificationRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = CreateService(db);

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.Rows.Should().Contain(row =>
            row.FinancialDept.Code == "D-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Financial Dept D-MISSING unclassified"));
        all.Rows.Should().Contain(row =>
            row.Account.Code == "A-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Account A-MISSING unclassified"));
        all.Rows.Should().Contain(row =>
            row.Activity.Code == "AC-MISSING" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Activity AC-MISSING unclassified"));
        all.Rows.Should().Contain(row =>
            row.Purpose.Code == "P-MISSING" &&
            row.Fund.Code == "F1" &&
            !row.Included &&
            row.ExclusionReasons.Any(reason => reason.Label == "Purpose P-MISSING unclassified"));
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
        var service = CreateService(db);
        await using var output = new MemoryStream();

        await service.WriteTransactionsCsvAsync(
            Cycle(),
            Request(
                includeState: ExpenseReviewIncludeState.Included,
                pageSize: 1,
                sortBy: "amount",
                sortDescending: true,
                filters: Filters(fund: ["F1"], source: ["AE"])),
            output,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray()).TrimStart('\ufeff');
        var lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        lines.Should().Equal(
            "Source,Entity,Fund,Financial Dept,Account,Purpose,Program,Project,Activity,SFN,Amount,Include State,Exclusion Reasons",
            "AE,3310 - Entity One,F1 - Fund One,D1 - Dept One,A1 - Account One,P1 - Purpose One,PG1 - Program One,PR1 - AE Project One,AC1 - Activity One,201 - Hatch,125.00,Included,");
    }

    [Fact]
    public async Task Transaction_csv_export_splits_mixed_include_state_groups()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = CreateService(db);
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
            line.Contains("AE account A1 also in UCPath · $402.00 · 1 row", StringComparison.Ordinal) &&
            line.Contains("Date excluded · $401.00 · 1 row", StringComparison.Ordinal));
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
                 '20000001', 'POS00001', 80.000000, 200.00, 0.500000, '2024-11-15', 'S', 2024, '5', 0, 0, 0, 0),
                ('UCP-ERN-MISSING', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E02',
                 '20000002', 'POS00002', 40.000000, 300.00, 0.250000, '2024-11-30', 'S', 2024, '5', 0, 0, 0, 0),
                ('UCP-OUTSIDE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000003', 'POS00003', 40.000000, 999.00, 0.250000, '2023-11-30', 'S', 2024, '5', 0, 0, 0, 0);
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
                 '20000004', 'POS00004', 10.000000, 403.00, 0.050000, '2024-11-30', 'S', 2024, '5', 0, 0, 1, 0),
                ('UCP-ACCOUNT-NOT-AE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PG1', 'PR1', 'AC1', 'E01',
                 '20000005', 'POS00005', 10.000000, 404.00, 0.050000, '2024-11-30', 'S', 2024, '5', 0, 0, 0, 1);
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
        ExpenseReviewFilters? filters = null) =>
        new(includeState, page, pageSize, sortBy, sortDescending, displayByPeriod, filters ?? Filters());

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

    private ExpenseReviewService CreateService(DataDbContext db)
    {
        var configuration = Configuration();
        return new ExpenseReviewService(db, configuration, new ExpenseReviewCacheService(db, configuration));
    }
}
