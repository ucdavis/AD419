using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class TransactionInclusionViewSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Included_applies_every_rule_and_the_531010_carve_out()
    {
        await fixture.ClearDataTablesAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1',   'Dept',            1, NULL),
                ('FinancialDepartment', 'DX',   'Excluded dept',   0, NULL),
                ('Fund',   'F201',  'Hatch fund',       1, '201'),
                ('Fund',   'F204',  'Grant fund',       1, '204'),
                ('Fund',   'FNONE', 'No SFN fund',      1, NULL),
                ('Fund',   '13U02', 'State',            1, '220'),
                ('Account', 'A1',     'Account',        1, NULL),
                ('Account', '531010', 'Academic salary', 1, NULL),
                ('Activity', 'AC1', 'Activity',         1, NULL),
                ('Purpose',  'P1',  'Purpose',          1, NULL),
                ('Purpose',  'PX',  'Excluded purpose', 0, NULL),
                ('Ern', 'REG', 'Regular', 1, NULL),
                ('Ern', 'BON', 'Bonus',   0, NULL);

            -- Reference labels each AE case.
            INSERT INTO [data].[AETransactions] ([Reference], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Amount], [ExcludedByDate], [AccountInUcPath])
            VALUES
                ('ae-included',        'F201', 'D1', 'A1', 'AC1', 'P1', 1, 0, 0),
                ('ae-date',            'F201', 'D1', 'A1', 'AC1', 'P1', 1, 1, 0),
                ('ae-account-ucpath',  'F201', 'D1', 'A1', 'AC1', 'P1', 1, 0, 1),
                ('ae-dept-excluded',   'F201', 'DX', 'A1', 'AC1', 'P1', 1, 0, 0),
                ('ae-purpose-excluded','F201', 'D1', 'A1', 'AC1', 'PX', 1, 0, 0),
                ('ae-13u02-purpose',   '13U02','D1', 'A1', 'AC1', 'PX', 1, 0, 0),
                ('ae-no-sfn',          'FNONE','D1', 'A1', 'AC1', 'P1', 1, 0, 0),
                ('ae-unclassified',    'F201', 'D1', 'A1', 'AC1', 'P1', 1, NULL, NULL),
                ('ae-531010-ignored',  'F201', 'D1', '531010', 'AC1', 'P1', 1, 0, 0);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-included',        '3310', 'F201', 'D1', 'D1', 'A1',     'P1', NULL, 'PR1', 'AC1', 'REG', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-531010-hatch',    '3310', 'F201', 'D1', 'D1', '531010', 'P1', NULL, 'PR1', 'AC1', 'REG', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-531010-grant',    '3310', 'F204', 'D1', 'D1', '531010', 'P1', NULL, 'PR1', 'AC1', 'REG', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-account-not-ae',  '3310', 'F201', 'D1', 'D1', 'A1',     'P1', NULL, 'PR1', 'AC1', 'REG', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 1),
                ('ucp-ern-excluded',    '3310', 'F201', 'D1', 'D1', 'A1',     'P1', NULL, 'PR1', 'AC1', 'BON', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0);
            """);

        var ae = (await connection.QueryAsync<AeRow>(
            """
            SELECT a.[Reference], i.[Included], i.[Account531010OnHatchFund], i.[ExpenseSfn], i.[FinancialDeptIncludeInReport], i.[PurposeIncludeInReport]
            FROM [data].[AETransactions] a
            JOIN [data].[v_TransactionInclusion] i ON i.[Source] = N'AE' AND i.[AeTransactionId] = a.[Id]
            """)).ToDictionary(row => row.Reference);

        ae.Should().HaveCount(9);
        ae["ae-included"].Included.Should().BeTrue();
        ae["ae-included"].ExpenseSfn.Should().Be("201");
        ae["ae-date"].Included.Should().BeFalse();
        ae["ae-account-ucpath"].Included.Should().BeFalse();
        ae["ae-dept-excluded"].Included.Should().BeFalse();
        ae["ae-dept-excluded"].FinancialDeptIncludeInReport.Should().BeFalse();
        ae["ae-purpose-excluded"].Included.Should().BeFalse();
        ae["ae-13u02-purpose"].Included.Should().BeTrue();
        ae["ae-13u02-purpose"].ExpenseSfn.Should().Be("220");
        ae["ae-no-sfn"].Included.Should().BeFalse();
        ae["ae-unclassified"].Included.Should().BeFalse();
        ae["ae-531010-ignored"].Included.Should().BeTrue();
        ae["ae-531010-ignored"].Account531010OnHatchFund.Should().BeFalse();

        var ucp = (await connection.QueryAsync<UcpRow>(
            """
            SELECT [LaborTransactionId], [Included], [Account531010OnHatchFund], [ErnIncludeInReport], [FteSfn]
            FROM [data].[v_TransactionInclusion]
            WHERE [Source] = N'UCPath'
            """)).ToDictionary(row => row.LaborTransactionId);

        ucp.Should().HaveCount(5);
        ucp["ucp-included"].Included.Should().BeTrue();
        ucp["ucp-included"].ErnIncludeInReport.Should().BeTrue();
        ucp["ucp-531010-hatch"].Included.Should().BeFalse();
        ucp["ucp-531010-hatch"].Account531010OnHatchFund.Should().BeTrue();
        ucp["ucp-531010-grant"].Included.Should().BeTrue();
        ucp["ucp-531010-grant"].Account531010OnHatchFund.Should().BeFalse();
        ucp["ucp-account-not-ae"].Included.Should().BeFalse();
        ucp["ucp-ern-excluded"].Included.Should().BeTrue();
        ucp["ucp-ern-excluded"].ErnIncludeInReport.Should().BeFalse();
    }

    private sealed record AeRow(string Reference, bool Included, bool Account531010OnHatchFund, string? ExpenseSfn, bool? FinancialDeptIncludeInReport, bool? PurposeIncludeInReport);

    private sealed record UcpRow(string LaborTransactionId, bool Included, bool Account531010OnHatchFund, bool? ErnIncludeInReport, string? FteSfn);
}
