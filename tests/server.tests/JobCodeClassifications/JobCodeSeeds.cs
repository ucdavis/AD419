using Dapper;
using Microsoft.Data.SqlClient;
using Server.Tests.SqlIntegration;

namespace Server.Tests.JobCodeClassifications;

// Payroll scenarios for job code classification. Every helper adds to
// SeedBaseScenarioAsync, which sets up fund F1 (included, SFN 201), fund F2
// (excluded), department D1 and ERN E01.
internal static class JobCodeSeeds
{
    public static async Task SeedBaseScenarioAsync(SqlServerDataDbFixture fixture)
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

    public static async Task SeedJobCodeRowsAsync(SqlServerDataDbFixture fixture)
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

    // Unassigned job codes whose FTE is not reported: zero FTE, or FTE only on
    // an ERN code classified excluded (an excluded ERN drops FTE, never dollars).
    public static async Task SeedJobCodeRowsWithoutReportedFteAsync(SqlServerDataDbFixture fixture)
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

    // Unassigned job codes with no reported FTE on State Appropriations (13U02),
    // the fund rule 220 associates by FTE line.
    public static async Task SeedJobCodeRowsOnStateAppropriationsAsync(SqlServerDataDbFixture fixture)
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

    // Unassigned job codes whose dollars or FTE net to zero across the job code
    // but not inside each expense summary row. BuildAutoAssociations keeps one
    // row per employee and chart string. Needs the 13U02 fund from
    // SeedJobCodeRowsOnStateAppropriationsAsync.
    public static async Task SeedJobCodeRowsOffsettingAcrossSummaryRowsAsync(SqlServerDataDbFixture fixture)
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

    // Unassigned job codes on rows the report drops: fund F2 is classified
    // excluded and department D-UNCLASSIFIED has no classification (fails closed).
    public static async Task SeedJobCodeRowsExcludedFromReportAsync(SqlServerDataDbFixture fixture)
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
}
