using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.AutoAssociations;
using Server.Tests.SqlIntegration;

namespace Server.Tests.AutoAssociations;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class AutoAssociationReportServiceSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    private static readonly DateTime CycleStart = new(2024, 10, 1);
    private static readonly DateTime CycleEnd = new(2025, 9, 30);

    [Fact]
    public async Task Build_report_is_null_before_a_build_and_populated_after()
    {
        await fixture.ClearDataTablesAsync();
        var service = CreateService();

        (await service.GetBuildAsync(CancellationToken.None)).Should().BeNull();

        await SeedAndBuildAsync();
        var build = await service.GetBuildAsync(CancellationToken.None);

        build.Should().NotBeNull();
        build!.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
        build.CycleEnd.Should().Be(new DateOnly(2025, 9, 30));
        build.SummaryRows.Should().Be(9);
        build.AssociationRows.Should().Be(11);
        build.ExcludedProjects.Should().Be(2);
        build.Misclassified204Rows.Should().Be(1);
    }

    [Fact]
    public async Task Excluded_projects_list_204_projects_under_100_with_their_ae_projects()
    {
        await fixture.ClearDataTablesAsync();
        await SeedAndBuildAsync();

        var rows = await CreateService().GetExcludedProjectsAsync(CancellationToken.None);

        rows.Select(row => (row.AccessionNumber, row.NifaProjectNumber, row.AeProjects, row.Total)).Should().Equal(
            ("1000009", "CA-D-ABC-1009-CG", "AE-Z", 0m),
            ("1000010", "CA-D-ABC-1010-CG", "AE-S", 80m));
        rows[1].Title.Should().Be("Small grant");
        rows[1].ProjectDirector.Should().Be("PI Seven");
    }

    [Fact]
    public async Task Fte_over_one_lists_employees_whose_summary_fte_exceeds_one()
    {
        await fixture.ClearDataTablesAsync();
        await SeedAndBuildAsync();

        var rows = await CreateService().GetFteOverOneAsync(CancellationToken.None);

        var row = rows.Should().ContainSingle().Subject;
        row.EmployeeId.Should().Be("E1");
        row.EmployeeName.Should().Be("PI One");
        row.Fte.Should().Be(1.300000m);
        row.RowCount.Should().Be(3);
    }

    [Fact]
    public async Task Pre_association_totals_group_by_orgr_department_and_sfn()
    {
        await fixture.ClearDataTablesAsync();
        await SeedAndBuildAsync();

        var rows = await CreateService().GetPreAssociationTotalsAsync(CancellationToken.None);

        rows.Select(row => (row.OrgR, row.FinancialDepartment, row.ExpenseSfn, row.Expenses, row.Fte)).Should().Equal(
            ("AAAA", "D1", "201", 750m, 0.660000m),
            ("AAAA", "D1", "202", 200m, 0.200000m),
            ("AAAA", "D1", "204", 1457m, 0m),
            ("AAAA", "D1", "220", 540m, 0.500000m));
        rows[0].SfnLabel.Should().Be("Hatch");
        rows[0].FinancialDepartmentName.Should().Be("Dept One");
    }

    // Reports for the three rules are asserted in Task 2's tests below this line.

    internal AutoAssociationReportService CreateService()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
            })
            .Build();
        return new AutoAssociationReportService(fixture.CreateDataDbContext(), configuration);
    }

    internal async Task SeedAndBuildAsync()
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

            INSERT INTO [data].[ChartSegments] ([SegmentName], [Code], [Description], [ValueDesc])
            VALUES ('FinancialDepartment', 'D1', 'Dept fallback', 'Dept One');

            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [FteSfn], [Description]) VALUES ('PROF', '241', 'Professors');
            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name]) VALUES ('1234', 'PROF', 'Professor');

            INSERT INTO [data].[OrgRs] ([Code]) VALUES ('AAAA');
            INSERT INTO [data].[OrgRFinancialDepartments] ([FinancialDepartment], [OrgR]) VALUES ('D1', 'AAAA');

            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [Title], [ProjectDirector], [UcpEmployeeId], [Is204], [Sfn], [AEProjectNumber])
            VALUES
                ('1000001', 'CA-D-ABC-1001-CG', 'Shared grant A',  'PI One',   'E1', 1, '204', 'AE-A'),
                ('1000002', 'CA-D-ABC-1002-CG', 'Shared grant B',  'PI Nine',  'E9', 1, '204', 'AE-A'),
                ('1000003', 'CA-D-ABC-1003-H',  'Hatch one',       'PI One',   'E1', 0, '201', NULL),
                ('1000004', 'CA-D-ABC-1004-H',  'Hatch two',       'PI One',   'E1', 0, '201', NULL),
                ('1000005', 'CA-D-ABC-1005-RR', 'Multi-state',     'PI One',   'E1', 0, '202', NULL),
                ('1000006', 'CA-D-ABC-1006-H',  'Hatch three',     'PI Two',   'E2', 0, '201', NULL),
                ('1000007', 'CA-D-ABC-1007-CG', 'Single grant',    'PI Three', 'E3', 1, '204', 'AE-B'),
                ('1000008', 'CA-D-ABC-1008-H',  'Hatch empty',     'PI Five',  'E5', 0, '201', NULL),
                ('1000009', 'CA-D-ABC-1009-CG', 'Empty grant',     'PI Six',   'E6', 1, '204', 'AE-Z'),
                ('1000010', 'CA-D-ABC-1010-CG', 'Small grant',     'PI Seven', 'E7', 1, '204', 'AE-S');

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
                ('ucp-201-e2',       '3310', 'F201',  'D1', 'D1', 'A1', 'P1', NULL, 'AE-C', 'AC1', 'REG', 'E2', 'PI Two', 'POS2', '1234', 10, 60,  0.060000, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);

            EXEC [data].[BuildAutoAssociations] @cycleStart, @cycleEnd;
            """,
            new { cycleStart = CycleStart, cycleEnd = CycleEnd });
    }
}
