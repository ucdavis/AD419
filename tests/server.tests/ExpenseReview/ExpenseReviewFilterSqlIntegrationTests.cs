using Dapper;
using FluentAssertions;
using FluentAssertions.Execution;
using Microsoft.Data.SqlClient;
using Server.ExpenseReview;
using Server.Models.ExpenseReview;

namespace Server.Tests.ExpenseReview;

public sealed partial class ExpenseReviewServiceSqlIntegrationTests
{
    [Fact]
    public async Task Dropdown_reasons_have_ordered_labels_and_filter_the_expected_facts_for_each_source()
    {
        await fixture.ClearDataTablesAsync();
        await SeedDropdownScenarioAsync();
        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration(), new ExpenseReviewFilterCache());
        var cases = new (string Code, string Label,
            Func<ExpenseReviewFilterOptionsResponse, IReadOnlyList<ExpenseReviewFilterOptionDto>> Field,
            string[] Ae, string[] Ucp)[]
        {
            ("aeAccountInUcPath", "AE account also in UCPath", o => o.AeProjects, ["PR1", "PR-MULTI"], []),
            ("account:excluded", "Excluded by account", o => o.Accounts, ["A-X"], ["A-X"]),
            ("activity:excluded", "Excluded by activity", o => o.Activities, ["AC-X"], ["AC-X"]),
            ("excludedByDate", "Excluded by date", o => o.AeProjects, ["PR1", "PR-MULTI"], ["PR1"]),
            ("financialDept:excluded", "Excluded by financial department", o => o.FinancialDepts, ["D-X"], ["D-X"]),
            ("fund:excluded", "Excluded by fund", o => o.Funds, ["F2"], []),
            ("purpose:excluded", "Excluded by purpose", o => o.Purposes, ["P-X"], ["P-X"]),
            ("sfn:unresolved", "No SFN derived for this transaction", o => o.Funds, [], ["MISSING"]),
            ("sfn:204NotOnProjectList", "SFN 204 project not on the project list", o => o.AeProjects, ["PR-OFF"], ["PR-OFF"]),
            ("account:531010", "UCPath account 531010 on a Hatch fund", o => o.Funds, [], ["F1"]),
            ("ucPathAccountNotInAE", "UCPath account missing from AE chart", o => o.AeProjects, [], ["PR1"]),
            ("account:unclassified", "Unclassified account", o => o.Accounts, ["A-MISSING", "A-NAMELESS"], ["A-NAMELESS", "MISSING"]),
            ("activity:unclassified", "Unclassified activity", o => o.Activities, ["AC-MISSING"], ["MISSING"]),
            ("financialDept:unclassified", "Unclassified financial department", o => o.FinancialDepts, ["D-MISSING"], ["MISSING"]),
            ("fund:unclassified", "Unclassified fund", o => o.Funds, [], ["MISSING"]),
            ("purpose:unclassified", "Unclassified purpose", o => o.Purposes, ["P-MISSING"], ["MISSING"]),
        };
        var all = await service.GetFilterOptionsAsync(Cycle(), Filters(), CancellationToken.None);
        using var assertions = new AssertionScope();
        all.ExclusionReasons.Should().Equal(cases.Select(test => new ExpenseReviewFilterOptionDto(test.Code, test.Label)));
        foreach (var test in cases)
        {
            foreach (var source in new[] { "ae", "ucp" })
            {
                var options = await service.GetFilterOptionsAsync(Cycle(),
                    Filters(source: [source], exclusionReason: [test.Code.ToUpperInvariant()]), CancellationToken.None);
                test.Field(options).Select(option => option.Value).Should().Equal(source == "ae" ? test.Ae : test.Ucp,
                    $"{source} rows matching {test.Code} should expose only their matching facts");
                // A null field can yield no options even when the transaction matched the reason.
                var hasRows = source == "ae"
                    ? test.Code != "account:531010" && test.Code != "ucPathAccountNotInAE"
                    : test.Code != "aeAccountInUcPath" && test.Code != "fund:excluded";
                options.Entities.Select(option => option.Value).Should().Equal(hasRows ? new[] { "3310" } : [],
                    $"{source} rows matching {test.Code} should determine entity availability");
            }
        }
        foreach (var filters in new[] { Filters(fund: ["13U02"]), Filters(aeProject: ["PR-204"]) })
        {
            var options = await service.GetFilterOptionsAsync(Cycle(), filters, CancellationToken.None);
            options.ExclusionReasons.Should().NotContain(option => option.Value.StartsWith("purpose:"));
        }
    }

    [Fact]
    public async Task Dropdown_labels_periods_and_cycle_boundaries_have_explicit_expected_values()
    {
        await fixture.ClearDataTablesAsync();
        await SeedDropdownScenarioAsync();
        await using var db = fixture.CreateDataDbContext();
        var service = new ExpenseReviewService(db, Configuration(), new ExpenseReviewFilterCache());
        var all = await service.GetFilterOptionsAsync(Cycle(), Filters(), CancellationToken.None);
        all.Accounts.Should().Contain(new ExpenseReviewFilterOptionDto("A-NAMELESS", "A-NAMELESS"));
        all.Entities.Should().Equal(new ExpenseReviewFilterOptionDto("3310", "3310 - Z chart entity"));
        all.Funds.Should().Contain(new ExpenseReviewFilterOptionDto("F1", "F1 - Z within cycle"));
        all.AccountingPeriods.Should().Equal(new[] { "Jul-24", "Oct-24", "Nov-24", "Dec-24", "Jan-25", "Jun-25", "Sep-25" }
            .Select(period => new ExpenseReviewFilterOptionDto(period, period)));
        all.AeProjects.Should().NotContain(option => option.Value.StartsWith("OUTSIDE"));
        foreach (var boundary in new[] { (Project: "BOUNDARY-START", Period: "Jul-24"), (Project: "BOUNDARY-6", Period: "Dec-24"),
            (Project: "BOUNDARY-7", Period: "Jan-25"), (Project: "BOUNDARY-12", Period: "Jun-25"), (Project: "BOUNDARY-END", Period: "Sep-25") })
        {
            var options = await service.GetFilterOptionsAsync(Cycle(),
                Filters(source: ["UCP"], aeProject: [boundary.Project]), CancellationToken.None);
            options.AccountingPeriods.Select(option => option.Value).Should().Equal(boundary.Period);
            var transactions = await service.GetTransactionsAsync(Cycle(),
                Request(displayByPeriod: true, filters: Filters(source: ["UCP"], aeProject: [boundary.Project],
                    accountingPeriod: [boundary.Period])), CancellationToken.None);
            transactions.Rows.Should().ContainSingle().Which.AccountingPeriod.Should().Be(boundary.Period);
        }
        foreach (var invalid in new[] { (Project: "INVALID-0", Fund: "F1"), (Project: "INVALID-13", Fund: "F1"),
            (Project: "INVALID-EMPTY", Fund: "F1"), (Project: "MISSING", Fund: "MISSING") })
        {
            var options = await service.GetFilterOptionsAsync(Cycle(),
                Filters(source: ["UCP"], aeProject: [invalid.Project]), CancellationToken.None);
            options.AccountingPeriods.Should().BeEmpty();
            options.Funds.Select(option => option.Value).Should().Equal(invalid.Fund);
            var transactions = await service.GetTransactionsAsync(Cycle(),
                Request(displayByPeriod: true, filters: Filters(source: ["UCP"], aeProject: [invalid.Project])),
                CancellationToken.None);
            transactions.Rows.Should().ContainSingle().Which.AccountingPeriod.Should().BeNull();
        }
    }

    [Fact]
    public async Task Concurrent_scoped_services_share_the_same_index()
    {
        await fixture.ClearDataTablesAsync();
        await SeedExpenseReviewScenarioAsync();
        var cache = new ExpenseReviewFilterCache();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var calls = Enumerable.Range(0, 12).Select(_ => Task.Run(async () =>
        {
            await start.Task;
            await using var db = fixture.CreateDataDbContext();
            return await new ExpenseReviewService(db, Configuration(), cache)
                .GetFilterOptionsAsync(Cycle(), Filters(), CancellationToken.None);
        })).ToArray();
        start.SetResult();
        var results = await Task.WhenAll(calls);
        results.Should().OnlyContain(result => ReferenceEquals(result, results[0]));
    }

    private async Task SeedDropdownScenarioAsync()
    {
        await SeedExpenseReviewScenarioAsync();
        await SeedPersistedExclusionFlagRowsAsync();
        await SeedMultiReasonTransactionAsync();
        await SeedAccount531010RowsAsync();
        await SeedMissingClassificationRowsAsync();
        await SeedFilterEdgeCasesAsync();
    }

    private async Task SeedFilterEdgeCasesAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.ExecuteAsync("""
            UPDATE data.ChartSegments SET Description = N'Z chart entity' WHERE SegmentName = N'Entity';
            INSERT data.SegmentClassifications (SegmentType, Code, IncludeInReport, Sfn) VALUES
                ('FinancialDepartment','D-X',0,NULL), ('Account','A-X',0,NULL),
                ('Activity','AC-X',0,NULL), ('Purpose','P-X',0,NULL), ('Fund','F204',1,'204');

            DECLARE @facts TABLE (Dept NVARCHAR(300), Fund NVARCHAR(300), Account NVARCHAR(300), Purpose NVARCHAR(300),
                Project NVARCHAR(300), Activity NVARCHAR(300), Period NVARCHAR(20), EndDate DATE, FiscalYear INT);
            INSERT @facts VALUES
                ('D-X','F1','A-X','P-X','PR1','AC-X','4','2024-10-01',2025),
                (NULL,NULL,NULL,NULL,NULL,NULL,'xx','2024-10-10',2025),
                ('D1','F204','A1','P1','PR-OFF','AC1','5','2024-11-30',2025),
                ('D1','13U02','A1','P-X','PR1','AC1','4','2024-10-01',2025),
                ('D1','F1','A1','P-X','PR-204','AC1','4','2024-10-01',2025),
                ('D1','F1','A1','P-MISSING','PR-204','AC1','4','2024-10-01',2025),
                ('D1','F1','A-NAMELESS','P1','INVALID-0','AC1','0','2024-12-01',2025),
                ('D1','F1','A1','P1','INVALID-13','AC1','13','2024-12-01',2025),
                ('D1','F1','A1','P1','INVALID-EMPTY','AC1','','2024-12-01',2025),
                ('D1','F1','A1','P1','BOUNDARY-START','AC1','1','2024-10-01',2025),
                ('D1','F1','A1','P1','BOUNDARY-6','AC1','6','2024-12-15',2025),
                ('D1','F1','A1','P1','BOUNDARY-7','AC1','7','2025-01-15',2025),
                ('D1','F1','A1','P1','BOUNDARY-12','AC1','12','2025-06-15',2025),
                ('D1','F1','A1','P1','BOUNDARY-END','AC1','3','2025-09-30',2026),
                ('D1','F1','A1','P1','OUTSIDE-BEFORE','AC1','3','2024-09-30',2025),
                ('D1','F1','A1','P1','OUTSIDE-AFTER','AC1','4','2025-10-01',2026);
            INSERT data.UcPathTransactions (LaborTransactionId, Entity, FinancialDepartment, Fund, Account, Purpose, Project,
                Activity, Program, Period, FiscalYear, PayPeriodEndDate, Amount, ExcludedByDate, AccountNotInAE,
                ParentDepartment, ErnCode, EmployeeId, PositionNumber, Hours, CalculatedFte, FringeBenefitSalaryCd, EmpRcd)
            SELECT CONCAT('EDGE-',ROW_NUMBER() OVER(ORDER BY (SELECT NULL))), '3310', COALESCE(Dept,'MISSING'), COALESCE(Fund,'MISSING'), COALESCE(Account,'MISSING'), COALESCE(Purpose,'MISSING'), COALESCE(Project,'MISSING'),
                COALESCE(Activity,'MISSING'), NULL, Period, FiscalYear, EndDate, 1, 0, 0,
                'D1', 'E01', '10000001', 'POS00001', 1, 1, 'S', 0 FROM @facts;
            INSERT data.AETransactions (Entity, FinancialDepartment, Fund, Account, Purpose, Project, Activity, Program,
                PeriodName, Amount, ExcludedByDate, AccountInUcPath, FundDescription, AccountDescription)
            SELECT '3310', Dept, Fund, Account, Purpose, Project, Activity, 'PG1',
                FORMAT(EndDate,'MMM-yy','en-US'),1,0,0,'Z within cycle','' FROM @facts;
            INSERT data.AETransactions (Entity, Fund, Project, PeriodName, FundDescription, Amount, ExcludedByDate, AccountInUcPath)
            VALUES ('3310','F1','OUTSIDE-BAD','invalid','ZZ invalid period',1,0,0),
                ('3310','F1','OUTSIDE-OLD','Sep-24','ZZ outside cycle',1,0,0),
                ('3310','F1','OUTSIDE-NEW','Oct-25','ZZ outside cycle',1,0,0);
            """);
    }
}
