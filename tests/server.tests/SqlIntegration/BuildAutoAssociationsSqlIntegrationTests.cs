using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

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

        build.SummaryRows.Should().Be(10);
        build.AssociationRows.Should().Be(12);
        build.ExcludedProjects.Should().Be(1);
        build.Misclassified204Rows.Should().Be(1);

        var summary = (await connection.QueryAsync<SummaryRow>(
            "SELECT [ExpenseId], [Source], [OrgR], [Project], [Fund], [EmployeeId], [AccessionNumber], [ExpenseSfn], [FteSfn], [Expenses], [Fte], [RuleExclusion] FROM [data].[ExpenseSummary]"))
            .ToList();

        summary.Should().HaveCount(10);
        summary.Where(row => row.Source == "AE" || row.Source == "UCPath").Should().OnlyContain(row => row.OrgR == "AAAA");
        summary.Single(row => row.Source == "AE" && row.Project == "AE-A" && row.Fund == "F204").Expenses.Should().Be(1000m);
        summary.Single(row => row.Source == "AE" && row.Project == "AE-B").Expenses.Should().Be(300m);
        var misclassified = summary.Single(row => row.Source == "AE" && row.Project == "AE-ZZ");
        misclassified.Expenses.Should().Be(77m);
        misclassified.RuleExclusion.Should().Be("Misclassified204");
        summary.Should().NotContain(row => row.Source == "AE" && row.Fund == "F201" && row.Project == "AE-A");
        var stateGroup = summary.Single(row => row.Source == "UCPath" && row.Fund == "13U02");
        stateGroup.Expenses.Should().Be(540m);
        stateGroup.Fte.Should().Be(0.500000m);
        stateGroup.ExpenseSfn.Should().Be("220");
        stateGroup.FteSfn.Should().Be("241");
        summary.Single(row => row.Source == "FieldStation").Should().BeEquivalentTo(
            new { AccessionNumber = "1000003", Expenses = 250m, Fte = 0m, ExpenseSfn = "22F", FteSfn = "241" });
        summary.Single(row => row.Source == "CE").Should().BeEquivalentTo(
            new { AccessionNumber = "1000004", Expenses = 20000m, Fte = 0.200000m, ExpenseSfn = "220", FteSfn = "242", EmployeeId = "E1" });

        var excluded = (await connection.QueryAsync<ExcludedRow>(
            "SELECT [AccessionNumber], [NifaProjectNumber], [Total] FROM [data].[AutoAssociationExcludedProjects]")).ToList();
        excluded.Should().ContainSingle().Which.Should().BeEquivalentTo(new ExcludedRow("1000006", "CA-D-ABC-1006-H", 60m));

        var staged = (await connection.QueryAsync<StagedRow>(
            """
            SELECT s.[Rule], s.[AccessionNumber], s.[OrgR], s.[AeProject], s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn], e.[Source], e.[Project], e.[Fund], e.[EmployeeId]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            """)).ToList();

        staged.Should().HaveCount(12);
        staged.Where(row => row.Rule == "204").Select(row => (row.AccessionNumber, row.Project, row.Expenses)).Should().BeEquivalentTo(
            new[] { ("1000001", "AE-A", 500m), ("1000002", "AE-A", 500m), ("1000007", "AE-B", 300m) });
        staged.Where(row => row.Rule == "20x").Select(row => (row.AccessionNumber, row.Fund, row.Expenses, row.Fte)).Should().BeEquivalentTo(
            new[] { ("1000003", "F201", 300m, 0.300000m), ("1000004", "F201", 300m, 0.300000m), ("1000005", "F202", 200m, 0.200000m) });
        staged.Where(row => row.Rule == "220").Select(row => (row.AccessionNumber, row.ExpenseSfn, row.Expenses, row.Fte)).Should().BeEquivalentTo(
            new[] { ("1000001", "220", 135m, 0.125000m), ("1000003", "220", 135m, 0.125000m), ("1000004", "220", 135m, 0.125000m), ("1000005", "220", 135m, 0.125000m) });
        staged.Single(row => row.Rule == "FS").Should().BeEquivalentTo(new { AccessionNumber = "1000003", Expenses = 250m, Fte = 0m, OrgR = "FS" });
        staged.Single(row => row.Rule == "CE").Should().BeEquivalentTo(new { AccessionNumber = "1000004", Expenses = 20000m, Fte = 0.200000m, OrgR = "AAAA", FteSfn = "242" });
        staged.Should().NotContain(row => row.AccessionNumber == "1000006");
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
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[ExpenseSummary]")).Should().Be(10);
        (await connection.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM [data].[StagedAssociations]")).Should().Be(12);

        await connection.ExecuteAsync("DELETE FROM [data].[Projects]");
        var act = () => connection.ExecuteAsync("EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd", new { cycleStart = CycleStart, cycleEnd = CycleEnd });
        await act.Should().ThrowAsync<SqlException>().WithMessage("*Projects*");
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
                ('1000007', 'CA-D-ABC-1007-CG', 'E3', 1, '204', 'AE-B');

            INSERT INTO [data].[AETransactions]
                ([Reference], [Entity], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Project], [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-204-shared',        '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Oct-24', 1000, 0, 0),
                ('ae-204-single',        '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-B',  'Nov-24', 300,  0, 0),
                ('ae-204-misclassified', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-ZZ', 'Nov-24', 77,   0, 0),
                ('ae-201-e1',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-C',  'Dec-24', 90,   0, 0),
                ('ae-zero-a',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Dec-24', 10,   0, 0),
                ('ae-zero-b',            '3310', 'F201', 'D1', 'A1', 'AC1', 'P1', 'AE-A',  'Jan-25', -10,  0, 0);

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

            INSERT INTO [data].[ad419_FieldStationExpenses] ([ProjectAccessionNum], [ProjectDirector], [FieldStationCharge])
            VALUES ('1000003', 'PI One', 250);

            INSERT INTO [data].[ad419_CESpecialists]
                ([DeptCode], [DeptName], [Pi], [DeptLevelOrg], [EmployeeId], [ProjectAccessionNum], [ProjectNumber], [PercentCeEffort], [FullAnnualPayRate], [TitleCode], [FTE], [Entity], [Exp SFN], [FTE SFN])
            VALUES ('D1', 'Dept', 'PI One', 'AAAA', 'E1', '1000004', 'CA-D-ABC-1004-H', 0.500000, 100000, '1234', 0.400000, '3310', '220', '242');
            """);
    }

    [Fact]
    public async Task Dry_run_counts_each_accession_once_and_exclusions_raise_survivor_shares()
    {
        await fixture.ClearDataTablesAsync();
        await SeedDryRunScenarioAsync();

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
            new ExcludedRow("2000003", "CA-D-XYZ-2003-H", 75m),
        });

        var staged = (await connection.QueryAsync<StagedRow>(
            """
            SELECT s.[Rule], s.[AccessionNumber], s.[OrgR], s.[AeProject], s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn], e.[Source], e.[Project], e.[Fund], e.[EmployeeId]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            """)).ToList();

        staged.Should().HaveCount(2);
        staged.Should().NotContain(row => row.Rule == "204");
        staged.Single(row => row.Rule == "20x").Should().BeEquivalentTo(
            new { AccessionNumber = "2000002", Expenses = 150m, Fte = 0.300000m, EmployeeId = "P2" });
        staged.Single(row => row.Rule == "FS").Should().BeEquivalentTo(
            new { AccessionNumber = "2000002", Expenses = 50m, Fte = 0m });
    }

    private async Task SeedDryRunScenarioAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label]) VALUES ('201', 'Hatch'), ('204', 'Grants');

            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1', 'Dept', 1, NULL),
                ('Fund', 'F204', 'Grant fund', 1, '204'),
                ('Fund', 'F201', 'Hatch fund', 1, '201'),
                ('Account', 'A1', 'Account', 1, NULL),
                ('Activity', 'AC1', 'Activity', 1, NULL),
                ('Purpose', 'P1', 'Purpose', 1, NULL),
                ('Ern', 'REG', 'Regular', 1, NULL);

            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA');
            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR]) VALUES ('D1', 'AAAA');

            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [UcpEmployeeId], [Is204], [Sfn], [AEProjectNumber])
            VALUES
                ('2000001', 'CA-D-XYZ-2001-CG', 'P1', 1, '204', 'AE-M1'),
                ('2000001', 'CA-D-XYZ-2001-CG', 'P1', 1, '204', 'AE-M2'),
                ('2000002', 'CA-D-XYZ-2002-H',  'P2', 0, '201', NULL),
                ('2000003', 'CA-D-XYZ-2003-H',  'P2', 0, '201', NULL);

            INSERT INTO [data].[AETransactions]
                ([Reference], [Entity], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Project], [PeriodName], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-m1', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-M1', 'Oct-24', 30, 0, 0),
                ('ae-m2', '3310', 'F204', 'D1', 'A1', 'AC1', 'P1', 'AE-M2', 'Oct-24', 40, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [EmployeeName], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-p2-201', '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-Q', 'AC1', 'REG', 'P2', 'PI Two', 'POS2', NULL, 10, 150, 0.300000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);

            INSERT INTO [data].[ad419_FieldStationExpenses] ([ProjectAccessionNum], [ProjectDirector], [FieldStationCharge])
            VALUES ('2000002', 'PI Two', 50);
            """);
    }

    private sealed record BuildRow(int BuildId, int SummaryRows, int AssociationRows, int ExcludedProjects, int Misclassified204Rows);

    private sealed record SummaryRow(int ExpenseId, string Source, string OrgR, string? Project, string? Fund, string? EmployeeId, string? AccessionNumber, string? ExpenseSfn, string? FteSfn, decimal Expenses, decimal Fte, string? RuleExclusion);

    private sealed record ExcludedRow(string AccessionNumber, string NifaProjectNumber, decimal Total);

    private sealed record StagedRow(string Rule, string AccessionNumber, string OrgR, string? AeProject, string? ExpenseSfn, decimal Expenses, decimal Fte, string? FteSfn, string Source, string? Project, string? Fund, string? EmployeeId);
}
