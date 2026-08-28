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
    public async Task Transaction_queries_apply_cycle_filters_classifications_counts_sorting_and_filter_options()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());
        var cycle = Cycle();

        var all = await service.GetTransactionsAsync(cycle, Request(), CancellationToken.None);

        all.Counts.Should().BeEquivalentTo(new ExpenseReviewCountsDto(4, 3, 1));
        var aeIncluded = all.Rows.Should().ContainSingle(row => row.Source == "AE" && row.Amount == 100m).Subject;
        long.TryParse(aeIncluded.SourceId, out _).Should().BeTrue();
        aeIncluded.Id.Should().Be($"AE:{aeIncluded.SourceId}");
        aeIncluded.AccountingPeriod.Should().Be("Oct-24");
        aeIncluded.Fte.Should().BeNull();
        aeIncluded.FteIncluded.Should().BeFalse();
        aeIncluded.Included.Should().BeTrue();
        aeIncluded.FinancialDept.Name.Should().Be("Dept One");
        aeIncluded.Fund.Name.Should().Be("Fund One");
        aeIncluded.Account.Name.Should().Be("Account One");
        aeIncluded.AeProject.Name.Should().Be("AE Project One");
        all.Rows.Should().Contain(row =>
            row.SourceId == "UCP-ERN-MISSING" &&
            row.Source == "UCP" &&
            row.AccountingPeriod == "Nov-24" &&
            row.Included &&
            !row.FteIncluded);
        var ucpIncluded = all.Rows.Should().ContainSingle(row => row.SourceId == "UCP-INCLUDED").Subject;
        ucpIncluded.Id.Should().Be("UCP:UCP-INCLUDED");
        ucpIncluded.Fte.Should().Be(0.5m);
        ucpIncluded.FteIncluded.Should().BeTrue();
        ucpIncluded.Included.Should().BeTrue();
        ucpIncluded.FinancialDept.Name.Should().Be("Dept One");
        ucpIncluded.Fund.Name.Should().Be("Fund One");
        ucpIncluded.Account.Name.Should().Be("Account One");
        ucpIncluded.AeProject.Name.Should().Be("Project One");
        all.Rows.Should().Contain(row =>
            row.Source == "AE" &&
            row.Fund.Code == "F2" &&
            !row.Included);
        all.Rows.Should().NotContain(row => row.Amount == 999m);

        var included = await service.GetTransactionsAsync(
            cycle,
            Request(
                includeState: ExpenseReviewIncludeState.Included,
                pageSize: 2,
                sortBy: "amount",
                sortDescending: true,
                filters: new ExpenseReviewFilters([], ["F1"], [], [], [], [], [])),
            CancellationToken.None);

        included.TotalCount.Should().Be(3);
        included.PageCount.Should().Be(2);
        included.Rows.Select(row => row.Amount).Should().Equal(300m, 200m);

        var ucPathOnly = await service.GetTransactionsAsync(
            cycle,
            Request(filters: new ExpenseReviewFilters([], [], [], [], [], ["UCP"], [])),
            CancellationToken.None);
        ucPathOnly.TotalCount.Should().Be(2);
        ucPathOnly.Rows.Should().OnlyContain(row => row.Source == "UCP");

        var excluded = await service.GetTransactionsAsync(
            cycle,
            Request(includeState: ExpenseReviewIncludeState.Excluded),
            CancellationToken.None);
        excluded.Rows.Should().ContainSingle(row => row.Fund.Code == "F2");

        var filters = await service.GetFilterOptionsAsync(cycle, CancellationToken.None);
        filters.FinancialDepts.Should().ContainSingle(option => option.Value == "D1" && option.Label == "Dept One");
        filters.Funds.Should().Contain(option => option.Value == "F1" && option.Label == "Fund One");
        filters.Accounts.Should().ContainSingle(option => option.Value == "A1" && option.Label == "Account One");
        filters.AeProjects.Should().ContainSingle(option => option.Value == "PR1" && option.Label == "Project One");
        filters.AccountingPeriods.Select(option => option.Value).Should().Contain(["Oct-24", "Nov-24"]);
        filters.Sources.Should().Contain(option => option.Value == "AE" && option.Label == "Aggie Enterprise");
        filters.Sources.Should().Contain(option => option.Value == "UCP" && option.Label == "UCPath");
        filters.Sfns.Should().ContainSingle(option => option.Value == "201" && option.Label == "Hatch");
    }

    [Fact]
    public async Task Transaction_queries_exclude_rows_with_persisted_exclusion_flags()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 401m && !row.Included);
        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 402m && !row.Included);
        all.Rows.Should().Contain(row => row.SourceId == "UCP-FLAG-EXCLUDED" && !row.Included);
        all.Rows.Should().Contain(row => row.SourceId == "UCP-ACCOUNT-NOT-AE" && !row.Included);
    }

    [Fact]
    public async Task Transaction_queries_fail_closed_for_missing_classifications_except_13u02_purpose()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        await SeedMissingClassificationRowsAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration());

        var all = await service.GetTransactionsAsync(Cycle(), Request(), CancellationToken.None);

        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 511m && !row.Included);
        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 512m && !row.Included);
        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 513m && !row.Included);
        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 514m && !row.Included);
        all.Rows.Should().Contain(row => row.Source == "AE" && row.Amount == 515m && row.Included);
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
                filters: new ExpenseReviewFilters([], ["F1"], [], [], [], [], [])),
            ["source", "amount", "included"],
            output,
            CancellationToken.None);

        var csv = Encoding.UTF8.GetString(output.ToArray()).TrimStart('\ufeff');
        var lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);

        lines.Should().Equal(
            "Source,Amount,Include State",
            "UCP,300.00,Included",
            "UCP,200.00,Included",
            "AE,100.00,Included");
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
                ('FinancialDepartment', 'D1', 'Financial Dept Fallback', 'Dept One'),
                ('Fund', 'F1', 'Fund Fallback', 'Fund One'),
                ('Fund', 'F2', 'Fund Two', 'Fund Two'),
                ('Account', 'A1', 'Account Fallback', 'Account One'),
                ('Project', 'PR1', 'Project Fallback', 'Project One');

            INSERT INTO [data].[AETransactions]
                ([Fund], [FinancialDepartment], [Account], [Purpose], [Project], [Activity],
                 [FundDescription], [FinancialDepartmentDescription], [AccountDescription], [ProjectDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('F1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'Fund One', 'Dept One', 'Account One', 'AE Project One', 'Oct-24', 100.00, 0, 0),
                ('F2', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'Fund Two', 'Dept One', 'Account One', 'Excluded Fund Project', 'Oct-24', 50.00, 0, 0),
                ('F1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'Fund One', 'Dept One', 'Account One', 'Outside Project', 'Oct-23', 999.00, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-INCLUDED', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'E01',
                 '20000001', 'POS00001', 80.000000, 200.00, 0.500000, '2024-11-15', 'S', 2024, '5', 0, 0, 0, 0),
                ('UCP-ERN-MISSING', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'E02',
                 '20000002', 'POS00002', 40.000000, 300.00, 0.250000, '2024-11-30', 'S', 2024, '5', 0, 0, 0, 0),
                ('UCP-OUTSIDE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'E01',
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
                ([Fund], [FinancialDepartment], [Account], [Purpose], [Project], [Activity],
                 [FundDescription], [FinancialDepartmentDescription], [AccountDescription], [ProjectDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('F1', 'D1', 'A1', 'P1', 'PR1', 'AC1',
                 'Fund One', 'Dept One', 'Account One', 'AE Flag Excluded', 'Oct-24', 401.00, 1, 0),
                ('F1', 'D1', 'A1', 'P1', 'PR1', 'AC1',
                 'Fund One', 'Dept One', 'Account One', 'AE Account In UCPath', 'Oct-24', 402.00, 0, 1);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('UCP-FLAG-EXCLUDED', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'E01',
                 '20000004', 'POS00004', 10.000000, 403.00, 0.050000, '2024-11-30', 'S', 2024, '5', 0, 0, 1, 0),
                ('UCP-ACCOUNT-NOT-AE', '3310', 'F1', 'D1', 'D1', 'A1', 'P1', 'PR1', 'AC1', 'E01',
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
                ([Fund], [FinancialDepartment], [Account], [Purpose], [Project], [Activity],
                 [FundDescription], [FinancialDepartmentDescription], [AccountDescription], [ProjectDescription],
                 [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('F1', 'D-MISSING', 'A1', 'P1', 'PR1', 'AC1',
                 'Fund One', 'Missing Dept', 'Account One', 'Missing Financial Dept', 'Oct-24', 511.00, 0, 0),
                ('F1', 'D1', 'A-MISSING', 'P1', 'PR1', 'AC1',
                 'Fund One', 'Dept One', 'Missing Account', 'Missing Account', 'Oct-24', 512.00, 0, 0),
                ('F1', 'D1', 'A1', 'P1', 'PR1', 'AC-MISSING',
                 'Fund One', 'Dept One', 'Account One', 'Missing Activity', 'Oct-24', 513.00, 0, 0),
                ('F1', 'D1', 'A1', 'P-MISSING', 'PR1', 'AC1',
                 'Fund One', 'Dept One', 'Account One', 'Missing Purpose Non-13U02', 'Oct-24', 514.00, 0, 0),
                ('13U02', 'D1', 'A1', 'P-MISSING', 'PR1', 'AC1',
                 'UC ANR Federal Flowthrough', 'Dept One', 'Account One', 'Missing Purpose 13U02', 'Oct-24', 515.00, 0, 0);
            """);
    }

    private static ExpenseReviewTransactionsRequest Request(
        ExpenseReviewIncludeState includeState = ExpenseReviewIncludeState.All,
        int page = 1,
        int pageSize = 50,
        string sortBy = ExpenseReviewRequestParser.DefaultSortBy,
        bool sortDescending = false,
        ExpenseReviewFilters? filters = null) =>
        new(includeState, page, pageSize, sortBy, sortDescending, filters ?? new ExpenseReviewFilters([], [], [], [], [], [], []));

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
