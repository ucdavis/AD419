using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class BuildAutoAssociationsSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    private static readonly DateTime CycleStart = new(2024, 10, 1);
    private static readonly DateTime CycleEnd = new(2025, 9, 30);

    [Fact]
    public async Task Build_summarizes_included_rows_excludes_small_projects_and_runs_every_rule()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        var build = await connection.QuerySingleAsync<BuildRow>(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        build.SummaryRows.Should().Be(8);
        build.AssociationRows.Should().Be(11);
        build.ExcludedProjects.Should().Be(2);
        build.Misclassified204Rows.Should().Be(0);

        var summary = (await connection.QueryAsync<SummaryRow>(
            "SELECT [ExpenseId], [Source], [OrgR], [Project], [Fund], [EmployeeId], [ExpenseSfn], [FteSfn], [Expenses], [Fte], [RuleExclusion] FROM [data].[ExpenseSummary]"))
            .ToList();

        summary.Should().HaveCount(8);
        summary.Should().OnlyContain(row => row.OrgR == "AAAA");
        summary.Single(row => row.Source == "AE" && row.Project == "AE-A" && row.Fund == "F204").Expenses.Should().Be(1000m);
        summary.Single(row => row.Source == "AE" && row.Project == "AE-B").Expenses.Should().Be(300m);
        // a 204 row off the 204 project list is excluded before the summary
        summary.Should().NotContain(row => row.Project == "AE-ZZ");
        summary.Should().NotContain(row => row.Source == "AE" && row.Fund == "F201" && row.Project == "AE-A");
        summary.Single(row => row.Source == "AE" && row.Project == "AE-S").Expenses.Should().Be(80m);
        var stateGroup = summary.Single(row => row.Source == "UCPath" && row.Fund == "13U02");
        stateGroup.Expenses.Should().Be(540m);
        stateGroup.Fte.Should().Be(0.500000m);
        stateGroup.ExpenseSfn.Should().Be("220");
        stateGroup.FteSfn.Should().Be("241");

        var excluded = (await connection.QueryAsync<ExcludedRow>(
            "SELECT [AccessionNumber], [NifaProjectNumber], [Total] FROM [data].[AutoAssociationExcludedProjects]")).ToList();
        excluded.Should().BeEquivalentTo(new[]
        {
            new ExcludedRow("1000009", "CA-D-ABC-1009-CG", 0m),
            new ExcludedRow("1000010", "CA-D-ABC-1010-CG", 80m),
        });

        var staged = (await connection.QueryAsync<StagedRow>(
            """
            SELECT s.[Rule], s.[AccessionNumber], s.[OrgR], s.[AeProject], s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn], e.[Source], e.[Project], e.[Fund], e.[EmployeeId]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            """)).ToList();

        staged.Should().HaveCount(11);
        staged.Where(row => row.Rule == "204").Select(row => (row.AccessionNumber, row.Project, row.Expenses)).Should().BeEquivalentTo(
            new[] { ("1000001", "AE-A", 500m), ("1000002", "AE-A", 500m), ("1000007", "AE-B", 300m) });
        staged.Where(row => row.Rule == "20x").Select(row => (row.AccessionNumber, row.Fund, row.Expenses, row.Fte)).Should().BeEquivalentTo(
            new[] { ("1000003", "F201", 300m, 0.300000m), ("1000004", "F201", 300m, 0.300000m), ("1000005", "F202", 200m, 0.200000m), ("1000006", "F201", 60m, 0.060000m) });
        staged.Where(row => row.Rule == "220").Select(row => (row.AccessionNumber, row.ExpenseSfn, row.Expenses, row.Fte)).Should().BeEquivalentTo(
            new[] { ("1000001", "220", 135m, 0.125000m), ("1000003", "220", 135m, 0.125000m), ("1000004", "220", 135m, 0.125000m), ("1000005", "220", 135m, 0.125000m) });
        staged.Should().NotContain(row => row.AccessionNumber == "1000010" || row.AccessionNumber == "1000009");
        staged.Should().NotContain(row => row.Project == "AE-ZZ");
        staged.Should().NotContain(row => row.Source == "AE" && row.Fund == "F201");
    }

    [Fact]
    public async Task Build_replaces_the_previous_build_and_throws_without_projects()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[AutoAssociationBuilds]")).Should().Be(1);
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[ExpenseSummary]")).Should().Be(8);
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[StagedAssociations]")).Should().Be(11);

        await connection.ExecuteAsync("DELETE FROM [data].[Projects]");
        var act = () => connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });
        await act.Should().ThrowAsync<SqlException>().WithMessage("*Projects*");
    }

    [Fact]
    public async Task Build_rejects_bad_parameters_and_missing_orgr_with_named_messages()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        var reversed = () => connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleEnd, cycleEnd = CycleStart });
        await reversed.Should().ThrowAsync<SqlException>().WithMessage("*must not be after*");

        await connection.ExecuteAsync("UPDATE [data].[OrgRFinancialDepartments] SET [OrgR] = NULL WHERE [FinancialDepartment] = 'D1'");
        var noOrgR = () => connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });
        await noOrgR.Should().ThrowAsync<SqlException>().WithMessage("*no OrgR*");
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[ExpenseSummary]")).Should().Be(0);
        await connection.ExecuteAsync("UPDATE [data].[OrgRFinancialDepartments] SET [OrgR] = 'AAAA' WHERE [FinancialDepartment] = 'D1'");
    }

    [Fact]
    public async Task Rejected_rebuild_leaves_the_previous_build_in_place()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        var window = new { cycleStart = CycleStart, cycleEnd = CycleEnd };
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);

        const string stateSql =
            """
            SELECT
                (SELECT MAX([BuildId]) FROM [data].[AutoAssociationBuilds]) AS [BuildId],
                (SELECT COUNT(*) FROM [data].[AutoAssociationBuilds]) AS [Builds],
                (SELECT COUNT(*) FROM [data].[ExpenseSummary]) AS [SummaryRows],
                (SELECT COUNT(*) FROM [data].[StagedAssociations]) AS [AssociationRows],
                (SELECT COUNT(*) FROM [data].[AutoAssociationExcludedProjects]) AS [ExcludedProjects],
                (SELECT SUM([Expenses]) FROM [data].[StagedAssociations]) AS [AssociatedExpenses]
            """;
        var before = await connection.QuerySingleAsync<StagingState>(stateSql);
        before.Should().Be(new StagingState(before.BuildId, 1, 8, 11, 2, before.AssociatedExpenses));

        // The rebuild button reruns the procedure over an existing build. The
        // no OrgR rejection is thrown after the procedure has deleted the old
        // staging rows, so only the rollback keeps them.
        await connection.ExecuteAsync("UPDATE [data].[OrgRFinancialDepartments] SET [OrgR] = NULL WHERE [FinancialDepartment] = 'D1'");
        var rebuild = () => connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", window);
        await rebuild.Should().ThrowAsync<SqlException>().WithMessage("*no OrgR*");

        (await connection.QuerySingleAsync<StagingState>(stateSql)).Should().Be(before);
        await connection.ExecuteAsync("UPDATE [data].[OrgRFinancialDepartments] SET [OrgR] = 'AAAA' WHERE [FinancialDepartment] = 'D1'");
    }

    private sealed record StagingState(int BuildId, int Builds, int SummaryRows, int AssociationRows, int ExcludedProjects, decimal AssociatedExpenses);

    [Fact]
    public async Task Summary_total_equals_expense_review_included_total()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();
        await connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        await using var db = fixture.CreateDataDbContext();
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:DataConnection"] = fixture.ConnectionString })
            .Build();
        var service = new Server.ExpenseReview.ExpenseReviewService(db, configuration);
        Server.Models.FiscalYearCycle.TryParse("FY25", out var cycle).Should().BeTrue();
        var review = await service.GetTransactionsAsync(
            cycle!,
            new Server.Models.ExpenseReview.ExpenseReviewTransactionsRequest(
                Server.Models.ExpenseReview.ExpenseReviewIncludeState.Included, 1, 500, "source", false, false, true,
                new Server.Models.ExpenseReview.ExpenseReviewFilters([], [], [], [], [], [], [], [], [], [], [], [])),
            CancellationToken.None);

        var reviewTotal = review.Rows.Sum(row => row.Amount ?? 0m);
        var summaryTotal = await connection.ExecuteScalarAsync<decimal>(
            "SELECT SUM([Expenses]) FROM [data].[ExpenseSummary] WHERE [Source] IN (N'AE', N'UCPath')");

        summaryTotal.Should().Be(reviewTotal);
    }

    [Fact]
    public async Task Pi_on_a_242_title_is_built_on_line_241_and_rule_220_takes_their_state_payroll()
    {
        await fixture.ClearDataTablesAsync();
        await SeedScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description]) VALUES ('SUPP', '242', 'Professional Support');
            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name]) VALUES ('3300', 'SUPP', 'Specialist');

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-13u02-e2-242', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E2', 'PI Two',   'POS2', '3300', 10, 100, 0.100000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-13u02-e7-242', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E7', 'PI Seven', 'POS7', '3300', 10, 50,  0.050000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-13u02-e8-242', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E8', 'Not A PI', 'POS8', '3300', 10, 70,  0.070000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);

        await connection.ExecuteAsync(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        var summary = (await connection.QueryAsync<SummaryRow>(
            "SELECT [ExpenseId], [Source], [OrgR], [Project], [Fund], [EmployeeId], [ExpenseSfn], [FteSfn], [Expenses], [Fte], [RuleExclusion] FROM [data].[ExpenseSummary] WHERE [Fund] = '13U02' AND [EmployeeId] IN ('E2', 'E7', 'E8')"))
            .ToDictionary(row => row.EmployeeId!);

        summary["E2"].FteSfn.Should().Be("241");
        summary["E7"].FteSfn.Should().Be("241");
        summary["E8"].FteSfn.Should().Be("242");

        var staged = (await connection.QueryAsync<StagedRow>(
            """
            SELECT s.[Rule], s.[AccessionNumber], s.[OrgR], s.[AeProject], s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn], e.[Source], e.[Project], e.[Fund], e.[EmployeeId]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            WHERE e.[Fund] = '13U02' AND e.[EmployeeId] IN ('E2', 'E7', 'E8')
            """)).ToList();

        // E2's state payroll follows them to their one project on line 241.
        // E7 is a PI but their only project is excluded under $100; E8 is not a PI.
        var row = staged.Should().ContainSingle().Subject;
        row.Rule.Should().Be("220");
        row.EmployeeId.Should().Be("E2");
        row.AccessionNumber.Should().Be("1000006");
        row.Expenses.Should().Be(100m);
        row.Fte.Should().Be(0.100000m);
        row.FteSfn.Should().Be("241");
    }

    private async Task SeedScenarioAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label]) VALUES ('201', 'Hatch'), ('202', 'Multi-State'), ('204', 'Grants'), ('220', 'State');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1', 'Dept', 1, NULL),
                ('Fund', 'F204',  'Grant fund', 1, '204'),
                ('Fund', 'F201',  'Hatch fund', 1, '201'),
                ('Fund', 'F202',  'Multi-state fund', 1, '202'),
                ('Fund', '13U02', 'State', 1, '220'),
                ('Account', 'A1', 'Account', 1, NULL),
                ('Activity', 'AC1', 'Activity', 1, NULL),
                ('Purpose', 'P1', 'Purpose', 1, NULL),
                ('Ern', 'REG', 'Regular', 1, NULL),
                ('Ern', 'BON', 'Bonus', 0, NULL);

            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description]) VALUES ('PROF', '241', 'Professors');
            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name]) VALUES ('1234', 'PROF', 'Professor');

            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA');
            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR]) VALUES ('D1', 'AAAA');

            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [UcpEmployeeId], [Is204], [Sfn], [AEProjectNumber])
            VALUES
                ('1000001', 'CA-D-ABC-1001-CG', 'E1', 1, '204', 'AE-A'),
                ('1000002', 'CA-D-ABC-1002-CG', 'E9', 1, '204', 'AE-A'),
                ('1000003', 'CA-D-ABC-1003-H',  'E1', 0, '201', NULL),
                ('1000004', 'CA-D-ABC-1004-H',  'E1', 0, '201', NULL),
                ('1000005', 'CA-D-ABC-1005-RR', 'E1', 0, '202', NULL),
                ('1000006', 'CA-D-ABC-1006-H',  'E2', 0, '201', NULL),
                ('1000007', 'CA-D-ABC-1007-CG', 'E3', 1, '204', 'AE-B'),
                ('1000008', 'CA-D-ABC-1008-H',  'E5', 0, '201', NULL),
                ('1000009', 'CA-D-ABC-1009-CG', 'E6', 1, '204', 'AE-Z'),
                ('1000010', 'CA-D-ABC-1010-CG', 'E7', 1, '204', 'AE-S');

            INSERT INTO [data].[AETransactions]
                ([Reference], [Entity], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Project], [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-204-shared',        '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Oct-24', 1000, 0, 0),
                ('ae-204-single',        '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-B',  'Nov-24', 300,  0, 0),
                ('ae-204-misclassified', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-ZZ', 'Nov-24', 77,   0, 0),
                ('ae-201-e1',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-C',  'Dec-24', 90,   0, 0),
                ('ae-zero-a',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Dec-24', 10,   0, 0),
                ('ae-zero-b',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Jan-25', -10,  0, 0),
                ('ae-204-small',         '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-S',  'Nov-24', 80,   0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-201-e1',       '3310', 'F201',  'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E1', 'PI One', 'POS1', '1234', 10, 600, 0.600000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-202-e1',       '3310', 'F202',  'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E1', 'PI One', 'POS1', '1234', 10, 200, 0.200000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-13u02-e1',     '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E1', 'PI One', 'POS1', '1234', 10, 500, 0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-13u02-e1-bon', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'BON', 'E1', 'PI One', 'POS1', '1234', 10, 40,  0.400000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-201-e2',       '3310', 'F201',  'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E2', 'PI Two', 'POS2', '1234', 10, 60,  0.060000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-outside',      '3310', 'F201',  'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E1', 'PI One', 'POS1', '1234', 10, 999, 0.900000, '2023-11-15', 'S', 2024, '5', 0, 0, 0, 0);
            """);
    }

    [Fact]
    public async Task Under_100_rule_applies_to_204_projects_on_direct_expenses_and_survivors_take_the_whole_share()
    {
        await fixture.ClearDataTablesAsync();
        await SeedUnder100ScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        var build = await connection.QuerySingleAsync<BuildRow>(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        build.SummaryRows.Should().Be(4);
        build.AssociationRows.Should().Be(2);
        build.ExcludedProjects.Should().Be(2);
        build.Misclassified204Rows.Should().Be(0);

        var excluded = (await connection.QueryAsync<ExcludedRow>(
            "SELECT [AccessionNumber], [NifaProjectNumber], [Total] FROM [data].[AutoAssociationExcludedProjects]")).ToList();
        excluded.Should().BeEquivalentTo(new[]
        {
            new ExcludedRow("2000001", "CA-D-XYZ-2001-CG", 70m),
            new ExcludedRow("2000003", "CA-D-XYZ-2003-CG", 0m),
        });

        var staged = (await connection.QueryAsync<StagedRow>(
            """
            SELECT s.[Rule], s.[AccessionNumber], s.[OrgR], s.[AeProject], s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn], e.[Source], e.[Project], e.[Fund], e.[EmployeeId]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            """)).ToList();

        staged.Should().HaveCount(2);
        staged.Single(row => row.Rule == "204").Should().BeEquivalentTo(
            new { AccessionNumber = "2000002", Project = "AE-N", Expenses = 300m });
        staged.Single(row => row.Rule == "220").Should().BeEquivalentTo(
            new { AccessionNumber = "2000002", ExpenseSfn = "220", Expenses = 150m, Fte = 0.300000m, EmployeeId = "P2" });
        staged.Should().NotContain(row => row.AccessionNumber == "2000001" || row.AccessionNumber == "2000003" || row.AccessionNumber == "2000004");
    }

    [Fact]
    public async Task Build_keeps_account_on_summary_rows_and_splits_rows_by_account()
    {
        await fixture.ClearDataTablesAsync();
        await SeedUnder100ScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        // Rows identical to the scenario's AE-N and P2 13U02 rows except for
        // the account, plus a pair on one account that nets to zero.
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('Account', '500000', 'Account', 1, NULL),
                ('Account', '520000', 'Account', 1, NULL),
                ('Account', '530000', 'Account', 1, NULL);

            INSERT INTO [data].[AETransactions]
                ([Reference], [Entity], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Project], [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-acct-a', '3310', 'F204', 'D1', '500000', 'AC1', 'P1', 'AE-N', 'Oct-24', 60,  0, 0),
                ('ae-acct-b', '3310', 'F204', 'D1', '520000', 'AC1', 'P1', 'AE-N', 'Oct-24', 40,  0, 0),
                ('ae-net-a',  '3310', 'F204', 'D1', '530000', 'AC1', 'P1', 'AE-N', 'Oct-24', 25,  0, 0),
                ('ae-net-b',  '3310', 'F204', 'D1', '530000', 'AC1', 'P1', 'AE-N', 'Nov-24', -25, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-acct-a', '3310', '13U02', 'D1', 'D1', '500000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two', 'POS2', '1234', 10, 100, 0.100000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-acct-b', '3310', '13U02', 'D1', 'D1', '520000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two', 'POS2', '1234', 10, 50,  0.050000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);

        await connection.ExecuteAsync(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        var summary = (await connection.QueryAsync<AccountRow>(
            "SELECT [Source], [Project], [Account], [Expenses], [Fte] FROM [data].[ExpenseSummary]")).ToList();

        summary.Where(row => row.Source == "AE" && row.Project == "AE-N")
            .Select(row => (row.Account, row.Expenses))
            .Should().BeEquivalentTo(new[] { ("A1", 300m), ("500000", 60m), ("520000", 40m) });
        summary.Where(row => row.Source == "UCPath" && row.Project == "AE-Q")
            .Select(row => (row.Account, row.Expenses, row.Fte))
            .Should().BeEquivalentTo(new[] { ("A1", 150m, 0.300000m), ("500000", 100m, 0.100000m), ("520000", 50m, 0.050000m) });
        summary.Should().NotContain(row => row.Account == "530000");
        summary.Sum(row => row.Expenses).Should().Be(770m);
    }

    [Fact]
    public async Task Build_keeps_fte_on_a_row_whose_dollars_net_to_zero()
    {
        await fixture.ClearDataTablesAsync();
        await SeedUnder100ScenarioAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        // P2 already has 150 and 0.3 FTE on account A1. On account 540000 a
        // payment with FTE is reversed by a correction with none, so the
        // account's dollars net to zero while its FTE does not. P4 has the
        // same pair and no other pay. Both keep their FTE.
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES ('Account', '540000', 'Account', 1, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-p2-pay',     '3310', '13U02', 'D1', 'D1', '540000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two',  'POS2', '1234', 10,  50, 0.500000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-p2-correct', '3310', '13U02', 'D1', 'D1', '540000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two',  'POS2', '1234', 0,  -50, 0.000000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0),
                ('ucp-p4-pay',     '3310', '13U02', 'D1', 'D1', '540000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P4', 'PI Four', 'POS4', '1234', 10,  50, 0.250000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-p4-correct', '3310', '13U02', 'D1', 'D1', '540000', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P4', 'PI Four', 'POS4', '1234', 0,  -50, 0.000000, '2024-12-15', 'S', 2025, '6', 0, 0, 0, 0);
            """);

        await connection.ExecuteAsync(
            "EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd",
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });

        var payroll = (await connection.QueryAsync<(string EmployeeId, string Account, decimal Expenses, decimal Fte)>(
            "SELECT [EmployeeId], [Account], [Expenses], [Fte] FROM [data].[ExpenseSummary] WHERE [Source] = N'UCPath'")).ToList();

        payroll.Should().BeEquivalentTo(new[]
        {
            ("P2", "A1", 150m, 0.300000m),
            ("P2", "540000", 0m, 0.500000m),
            ("P4", "540000", 0m, 0.250000m),
        });

        // Rule 220 carries P2's kept FTE to P2's project with no dollars. P4
        // has no project, so its row is left for manual association.
        var staged = await connection.QuerySingleAsync<(decimal Expenses, decimal Fte)>(
            "SELECT SUM([Expenses]), SUM([Fte]) FROM [data].[StagedAssociations] WHERE [Rule] = N'220'");
        staged.Should().Be((150m, 0.800000m));
    }

    private sealed record AccountRow(string Source, string? Project, string? Account, decimal Expenses, decimal Fte);

    private async Task SeedUnder100ScenarioAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label]) VALUES ('201', 'Hatch'), ('204', 'Grants'), ('220', 'State');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1', 'Dept', 1, NULL),
                ('Fund', 'F204',  'Grant fund', 1, '204'),
                ('Fund', '13U02', 'State', 1, '220'),
                ('Account', 'A1', 'Account', 1, NULL),
                ('Activity', 'AC1', 'Activity', 1, NULL),
                ('Purpose', 'P1', 'Purpose', 1, NULL),
                ('Ern', 'REG', 'Regular', 1, NULL);

            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description]) VALUES ('PROF', '241', 'Professors');
            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name]) VALUES ('1234', 'PROF', 'Professor');

            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA');
            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR]) VALUES ('D1', 'AAAA');

            -- 2000001: one 204 accession on two AE projects, 30 + 40 = 70 (under 100).
            -- 2000002: P2's 204 project with 300 of AE expenses.
            -- 2000003: P2's second 204 project with no expenses (excluded at 0), so
            --          P2's 13U02 salary goes whole to 2000002.
            -- 2000004: a 201 project with no expenses; non-204, never excluded.
            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [UcpEmployeeId], [Is204], [Sfn], [AEProjectNumber])
            VALUES
                ('2000001', 'CA-D-XYZ-2001-CG', 'P1', 1, '204', 'AE-M1'),
                ('2000001', 'CA-D-XYZ-2001-CG', 'P1', 1, '204', 'AE-M2'),
                ('2000002', 'CA-D-XYZ-2002-CG', 'P2', 1, '204', 'AE-N'),
                ('2000003', 'CA-D-XYZ-2003-CG', 'P2', 1, '204', 'AE-T'),
                ('2000004', 'CA-D-XYZ-2004-H',  'P3', 0, '201', NULL);

            INSERT INTO [data].[AETransactions]
                ([Reference], [Entity], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Project], [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-m1', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-M1', 'Oct-24', 30,  0, 0),
                ('ae-m2', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-M2', 'Oct-24', 40,  0, 0),
                ('ae-n',  '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-N',  'Oct-24', 300, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-p2-13u02', '3310', '13U02', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two', 'POS2', '1234', 10, 150, 0.300000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);
    }

    private sealed record BuildRow(int BuildId, int SummaryRows, int AssociationRows, int ExcludedProjects, int Misclassified204Rows);

    private sealed record SummaryRow(int ExpenseId, string Source, string OrgR, string? Project, string? Fund, string? EmployeeId, string? ExpenseSfn, string? FteSfn, decimal Expenses, decimal Fte, string? RuleExclusion);

    private sealed record ExcludedRow(string AccessionNumber, string NifaProjectNumber, decimal Total);

    private sealed record StagedRow(string Rule, string AccessionNumber, string OrgR, string? AeProject, string? ExpenseSfn, decimal Expenses, decimal Fte, string? FteSfn, string Source, string? Project, string? Fund, string? EmployeeId);
}
