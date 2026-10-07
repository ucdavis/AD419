using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class ClassificationCandidatesViewSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Candidates_are_codes_on_rows_that_pass_every_other_rule()
    {
        await fixture.ClearDataTablesAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description], [IncludeInReport], [Sfn])
            VALUES
                ('FinancialDepartment', 'D1', 'Dept',          1, NULL),
                ('FinancialDepartment', 'DX', 'Excluded dept', 0, NULL),
                ('Fund',    'F201',  'Hatch fund', 1, '201'),
                ('Fund',    '13U02', 'State',      1, '220'),
                ('Account', 'A1', 'Account',          1, NULL),
                ('Account', 'AX', 'Excluded account', 0, NULL),
                ('Purpose', 'P1', 'Purpose',          1, NULL),
                ('Purpose', 'PX', 'Excluded purpose', 0, NULL);

            INSERT INTO [data].[Projects] ([AccessionNumber], [NifaProjectNumber], [Is204], [Sfn], [AEProjectNumber])
            VALUES ('1000204', 'CA-D-XYZ-0001-CG', 1, '204', 'PRJ204');

            -- Each row carries its own activity code, so the activity list
            -- shows which rows count. Other codes are unique where a case
            -- tests that segment type.
            INSERT INTO [data].[AETransactions] ([Reference], [Fund], [FinancialDepartment], [Account], [Activity], [Purpose], [Amount], [ExcludedByDate], [AccountInUcPath], [Project])
            VALUES
                ('passes',            'F201',  'D1',      'A1',      'AC-PASS',     'P1',      1, 0, 0, NULL),
                ('dept-excluded',     'F201',  'DX',      'A1',      'AC-DEPT-X',   'P1',      1, 0, 0, NULL),
                ('dept-blank',        'F201',  'D-BLANK', 'A1',      'AC-DEPT-B',   'P1',      1, 0, 0, NULL),
                ('account-excluded',  'F201',  'D-ACCT',  'AX',      'AC-ACCT-X',   'P1',      1, 0, 0, NULL),
                ('purpose-excluded',  'F201',  'D1',      'A1',      'AC-PURP-X',   'PX',      1, 0, 0, NULL),
                ('purpose-13u02',     '13U02', 'D1',      'A1',      'AC-13U02',    'PX',      1, 0, 0, NULL),
                ('purpose-204',       'F201',  'D1',      'A1',      'AC-204',      'P-EXEMPT',1, 0, 0, 'PRJ204'),
                ('date-excluded',     'F201',  'D1',      'A1',      'AC-DATE',     'P1',      1, 1, 0, NULL),
                ('account-in-ucpath', 'F201',  'D1',      'A1',      'AC-INUCP',    'P1',      1, 0, 1, NULL),
                ('fund-blank',        'F-NEW', 'D1',      'A1',      'AC-FUND-B',   'P1',      1, 0, 0, NULL),
                ('fund-excl-dept',    'F-DX',  'DX',      'A1',      'AC-FUND-DX',  'P1',      1, 0, 0, NULL);

            INSERT INTO [data].[UcPathTransactions]
                ([LaborTransactionId], [Entity], [Fund], [FinancialDepartment], [ParentDepartment], [Account],
                 [Purpose], [Program], [Project], [Activity], [ErnCode], [EmployeeId], [PositionNumber], [JobCode],
                 [Hours], [Amount], [CalculatedFte], [PayPeriodEndDate], [FringeBenefitSalaryCd],
                 [FiscalYear], [Period], [EmpRcd], [EffSeq], [ExcludedByDate], [AccountNotInAE])
            VALUES
                ('ucp-passes',      '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC-PASS', 'REG', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-dept-x',      '3310', 'F201', 'DX', 'DX', 'A1', 'P1', NULL, 'PR1', 'AC-PASS', 'BON', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 0),
                ('ucp-not-in-ae',   '3310', 'F201', 'D1', 'D1', 'A1', 'P1', NULL, 'PR1', 'AC-PASS', 'OVT', '1', 'POS1', NULL, 1, 1, 0.1, '2024-11-15', 'S', 2025, '5', 0, 0, 0, 1);
            """);

        var candidates = (await connection.QueryAsync<(string SegmentType, string Code)>(
            "SELECT [SegmentType], [Code] FROM [data].[v_ClassificationCandidates]"))
            .ToHashSet();

        bool Has(string type, string code) => candidates.Contains((type, code));

        // Activity: only rows passing date, overlap, SFN, dept, account and purpose.
        Has("Activity", "AC-PASS").Should().BeTrue();
        Has("Activity", "AC-DEPT-B").Should().BeTrue("a blank department does not hide");
        Has("Activity", "AC-13U02").Should().BeTrue("13U02 is purpose exempt");
        Has("Activity", "AC-204").Should().BeTrue("204 projects are purpose exempt");
        Has("Activity", "AC-DEPT-X").Should().BeFalse();
        Has("Activity", "AC-ACCT-X").Should().BeFalse();
        Has("Activity", "AC-PURP-X").Should().BeFalse();
        Has("Activity", "AC-DATE").Should().BeFalse();
        Has("Activity", "AC-INUCP").Should().BeFalse();
        Has("Activity", "AC-FUND-B").Should().BeFalse("an unclassified fund leaves no expense SFN");

        // A code's own classification never hides it.
        Has("FinancialDepartment", "DX").Should().BeTrue("an excluded department stays visible");
        Has("FinancialDepartment", "D-BLANK").Should().BeTrue();
        Has("FinancialDepartment", "D-ACCT").Should().BeFalse("its only row has an excluded account");
        Has("Account", "AX").Should().BeTrue("an excluded account stays visible");
        Has("Purpose", "PX").Should().BeTrue("its non-exempt row passes the other rules");

        // Purpose codes only matter on rows that are not purpose exempt.
        Has("Purpose", "P-EXEMPT").Should().BeFalse();

        // Fund ignores the SFN rules, since its own classification sets the SFN.
        Has("Fund", "F-NEW").Should().BeTrue();
        Has("Fund", "F-DX").Should().BeFalse("its only row has an excluded department");

        // ERN codes come from UCPath rows that pass.
        Has("Ern", "REG").Should().BeTrue();
        Has("Ern", "BON").Should().BeFalse();
        Has("Ern", "OVT").Should().BeFalse();
    }
}
