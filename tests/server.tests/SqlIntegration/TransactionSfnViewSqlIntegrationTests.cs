using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class TransactionSfnViewSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task ExpenseSfn_resolves_in_order_13u02_fund_classification_project_list_then_pgm_award()
    {
        await fixture.ClearDataTablesAsync();
        await SeedReferenceDataAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        // Reference is the per-row label the assertions key on.
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[AETransactions] ([Reference], [Fund], [Project], [Amount])
            VALUES
                ('13u02-beats-classified-fund', '13U02',  'AE-204',      1),
                ('13u02-no-project',            '13U02',  NULL,          1),
                ('classified-fund',             'F201',   'AE-204',      1),
                ('multiple-project-list',       'FMULTI', 'AE-204',      1),
                ('multiple-pgm-award',          'FMULTI', 'AE-NSF',      1),
                ('multiple-conflicting-list',   'FMULTI', 'AE-CONFLICT', 1),
                ('multiple-unknown-list',       'FMULTI', 'AE-UNKNOWN',  1),
                ('multiple-hatch-award',        'FMULTI', 'AE-HATCH',    1),
                ('multiple-no-project',         'FMULTI', NULL,          1),
                ('unclassified-fund',           'FNONE',  'AE-204',      1),
                ('null-sfn-fund',               'FNULL',  'AE-204',      1),
                ('multiple-unknown-plus-concrete', 'FMULTI', 'AE-UNKNOWN-PLUS', 1),
                ('multiple-conflicting-award',   'FMULTI', 'AE-PGM-CONFLICT', 1);
            """);

        var rows = (await connection.QueryAsync<AeRow>(
            """
            SELECT a.[Reference], s.[ExpenseSfn], s.[ExpenseSfnSource], s.[FteSfn]
            FROM [data].[AETransactions] a
            JOIN [data].[v_TransactionSfn] s
                ON s.[Source] = N'AE' AND s.[AeTransactionId] = a.[Id]
            """)).ToDictionary(row => row.Reference);

        rows.Should().HaveCount(13);
        rows["13u02-beats-classified-fund"].Should().BeEquivalentTo(new AeRow("13u02-beats-classified-fund", "220", "Fund13U02", null));
        rows["13u02-no-project"].Should().BeEquivalentTo(new AeRow("13u02-no-project", "220", "Fund13U02", null));
        rows["classified-fund"].Should().BeEquivalentTo(new AeRow("classified-fund", "201", "FundClassification", null));
        rows["multiple-project-list"].Should().BeEquivalentTo(new AeRow("multiple-project-list", "204", "ProjectList", null));
        rows["multiple-pgm-award"].Should().BeEquivalentTo(new AeRow("multiple-pgm-award", "209", "PgmAward", null));
        rows["multiple-conflicting-list"].Should().BeEquivalentTo(new AeRow("multiple-conflicting-list", null, null, null));
        rows["multiple-unknown-list"].Should().BeEquivalentTo(new AeRow("multiple-unknown-list", null, null, null));
        rows["multiple-hatch-award"].Should().BeEquivalentTo(new AeRow("multiple-hatch-award", null, null, null));
        rows["multiple-no-project"].Should().BeEquivalentTo(new AeRow("multiple-no-project", null, null, null));
        rows["unclassified-fund"].Should().BeEquivalentTo(new AeRow("unclassified-fund", null, null, null));
        rows["null-sfn-fund"].Should().BeEquivalentTo(new AeRow("null-sfn-fund", null, null, null));
        rows["multiple-unknown-plus-concrete"].Should().BeEquivalentTo(new AeRow("multiple-unknown-plus-concrete", "204", "ProjectList", null));
        rows["multiple-conflicting-award"].Should().BeEquivalentTo(new AeRow("multiple-conflicting-award", null, null, null));
    }

    [Fact]
    public async Task FteSfn_follows_job_code_to_title_to_staff_type_line_for_ucpath_rows_only()
    {
        await fixture.ClearDataTablesAsync();
        await SeedReferenceDataAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq])
            VALUES
                ('full-chain',           '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'REG', '1', 'POS1', '1234', 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0),
                ('fringe-full-chain',    '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'XXX', '1', 'POS1', '1234', 0, 1, 0,   '2024-11-15', 'F', 2025, '5', 0, 0),
                ('no-title',             '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'REG', '2', 'POS2', '0000', 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0),
                ('title-no-staff-type',  '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'REG', '3', 'POS3', '5678', 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0),
                ('staff-type-no-line',   '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'REG', '4', 'POS4', '9999', 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0),
                ('missing-job-code',     '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'AE-204', 'AC1', 'REG', '5', 'POS5', NULL,   1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0);

            INSERT INTO [data].[AETransactions] ([Reference], [Fund], [Project], [Amount])
            VALUES ('ae-row', 'F201', 'AE-204', 1);
            """);

        var ucPathRows = (await connection.QueryAsync<UcPathRow>(
            """
            SELECT [TransactionId], [ExpenseSfn], [FteSfn]
            FROM [data].[v_TransactionSfn]
            WHERE [Source] = N'UCPath'
            """)).ToDictionary(row => row.TransactionId);

        ucPathRows.Should().HaveCount(6);
        ucPathRows["full-chain"].Should().BeEquivalentTo(new UcPathRow("full-chain", "201", "241"));
        ucPathRows["fringe-full-chain"].Should().BeEquivalentTo(new UcPathRow("fringe-full-chain", "201", "241"));
        ucPathRows["no-title"].Should().BeEquivalentTo(new UcPathRow("no-title", "201", null));
        ucPathRows["title-no-staff-type"].Should().BeEquivalentTo(new UcPathRow("title-no-staff-type", "201", null));
        ucPathRows["staff-type-no-line"].Should().BeEquivalentTo(new UcPathRow("staff-type-no-line", "201", null));
        ucPathRows["missing-job-code"].Should().BeEquivalentTo(new UcPathRow("missing-job-code", "201", null));

        var aeRow = await connection.QuerySingleAsync<UcPathRow>(
            """
            SELECT [TransactionId], [ExpenseSfn], [FteSfn]
            FROM [data].[v_TransactionSfn]
            WHERE [Source] = N'AE'
            """);
        aeRow.ExpenseSfn.Should().Be("201");
        aeRow.FteSfn.Should().BeNull();
    }

    private async Task SeedReferenceDataAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('Fund', '13U02',  'State appropriations', 1, '220'),
                ('Fund', 'F201',   'Hatch fund',           1, '201'),
                ('Fund', 'FMULTI', 'Grant fund',           1, 'Multiple'),
                ('Fund', 'FNULL',  'Unset fund',           1, NULL);

            INSERT INTO [data].[Projects]
                ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES
                ('1000001', 'CA-D-ABC-1001-CG', 1, '204',     'AE-204'),
                ('1000002', 'CA-D-ABC-1002-H',  0, '201',     'AE-CONFLICT'),
                ('1000003', 'CA-D-ABC-1003-RR', 0, '202',     'AE-CONFLICT'),
                ('1000004', 'CA-D-ABC-1004-XX', 0, 'UNKNOWN', 'AE-UNKNOWN'),
                ('1000005', 'CA-D-ABC-1005-XX', 0, 'UNKNOWN', 'AE-UNKNOWN-PLUS'),
                ('1000006', 'CA-D-ABC-1006-CG', 1, '204',     'AE-UNKNOWN-PLUS');

            INSERT INTO [data].[AssistanceListingNumbers] ([ProgramNumber], [FederalAgency030])
            VALUES
                ('47.041', 'NATIONAL SCIENCE FOUNDATION'),
                ('10.203', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('10.001', 'AGRICULTURAL RESEARCH SERVICE, AGRICULTURE, DEPARTMENT OF');

            INSERT INTO [data].[PGMProjects] ([ProjectId], [ProjectNumber], [CfdaProgramNumber], [SponsorAwardKey])
            VALUES
                (1, 'AE-NSF',   '47.041', 'AWD-NSF'),
                (2, 'AE-HATCH', '10.203', 'AWD-HATCH'),
                (3, 'AE-PGM-CONFLICT', '47.041', 'AWD-C1'),
                (4, 'AE-PGM-CONFLICT', '10.001', 'AWD-C2');

            INSERT INTO [data].[StaffTypes] ([StaffTypeCode], [Ad419LineNum], [Description])
            VALUES
                ('PROF', '241', 'Professors'),
                ('NOLINE', NULL, 'Not yet classified');

            INSERT INTO [data].[Titles] ([TitleCode], [StaffTypeCode], [Name])
            VALUES
                ('1234', 'PROF',   'Professor'),
                ('5678', NULL,     'Unclassified title'),
                ('9999', 'NOLINE', 'Title with lineless staff type');
            """);
    }

    private sealed record AeRow(string Reference, string? ExpenseSfn, string? ExpenseSfnSource, string? FteSfn);

    private sealed record UcPathRow(string TransactionId, string? ExpenseSfn, string? FteSfn);
}
