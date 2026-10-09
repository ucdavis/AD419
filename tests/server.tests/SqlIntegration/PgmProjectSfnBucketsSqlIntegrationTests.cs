using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class PgmProjectSfnBucketsSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task PgmSfnBucket_classifies_awards_by_aln_catalog()
    {
        await fixture.ClearDataTablesAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[AssistanceListingNumbers] ([ProgramNumber], [FederalAgency030])
            VALUES
                ('10.203', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('10.202', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('10.205', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('10.310', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('47.041', 'NATIONAL SCIENCE FOUNDATION');

            INSERT INTO [data].[PGMProjects] ([ProjectId], [ProjectNumber], [CfdaProgramNumber], [SponsorAwardKey])
            VALUES
                (1, 'P-HATCH',   '10.203', 'AWD1'),
                (2, 'P-MCS',     '10.202', 'AWD2'),
                (3, 'P-AH',      '10.205', 'AWD3'),
                (4, 'P-NIFA',    '10.310', 'AWD4'),
                (5, 'P-NSF',     '47.041', 'AWD5'),
                (6, 'P-NOMATCH', '99.999', 'AWD6'),
                (7, 'P-NOALN',   NULL,     'AWD7');
            """);

        var buckets = (await connection.QueryAsync<(string ProjectNumber, string? PgmSfnBucket)>(
            "SELECT [ProjectNumber], [PgmSfnBucket] FROM [data].[v_PgmProjectSfnBuckets]"))
            .ToDictionary(row => row.ProjectNumber, row => row.PgmSfnBucket);

        buckets["P-HATCH"].Should().Be("HATCH");
        buckets["P-MCS"].Should().Be("203");
        buckets["P-AH"].Should().Be("205");
        buckets["P-NIFA"].Should().Be("204");
        buckets["P-NSF"].Should().Be("NON-NIFA");
        buckets["P-NOMATCH"].Should().BeNull();
        buckets["P-NOALN"].Should().BeNull();
    }

    [Fact]
    public async Task PgmSfn_applies_last_years_rules_in_order()
    {
        await fixture.ClearDataTablesAsync();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[AssistanceListingNumbers] ([ProgramNumber], [FederalAgency030])
            VALUES
                ('10.203', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('10.310', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE, AGRICULTURE, DEPARTMENT OF'),
                ('93.847', 'NATIONAL INSTITUTES OF HEALTH, HEALTH AND HUMAN SERVICES, DEPARTMENT OF'),
                ('93.001', 'HEALTH AND HUMAN SERVICES, DEPARTMENT OF');

            INSERT INTO [data].[PGMProjects]
                ([ProjectId], [ProjectNumber], [CfdaProgramNumber], [AwardNumber], [AwardType], [AwardDescription],
                 [PrimarySponsorName], [FundingSourceName], [FlowThroughPrimarySponsor], [FlowThroughFederalAgency])
            VALUES
                (1,  'HATCH-AWD',   NULL,     '21005', NULL, NULL, NULL, NULL, NULL, NULL),
                (2,  'HATCH-DESC',  NULL,     'X1', NULL, 'HATCH PROJECT', NULL, NULL, NULL, NULL),
                (3,  'MS-DESC',     NULL,     'X2', NULL, 'HATCH MULTI STATE W1234', NULL, NULL, NULL, NULL),
                (4,  'HATCH-ALN',   '10.203', 'X3', NULL, NULL, NULL, NULL, NULL, NULL),
                (5,  'NIFA-FT',     '10.310', 'X4', '11-Non-Profit - Grants', NULL, 'SOME UNIVERSITY', NULL,
                     'NATIONAL INSTITUTE FOR FOOD AND AGRICULTURE', 'Y'),
                (6,  'NIFA-SPONSOR', NULL,    'X5', NULL, NULL, 'NATIONAL INSTITUTE FOR FOOD AND AGRICULTURE', NULL, NULL, NULL),
                (7,  'NIFA-ALN-NO-SPONSOR', '10.310', 'X6', NULL, NULL, 'SOME UNIVERSITY', NULL, NULL, NULL),
                (20, 'USDA-ALN',    '10.001', 'X19', NULL, NULL, 'SOME UNIVERSITY', NULL, NULL, NULL),
                (8,  'USDA-FT',     NULL,     'X7', '15-Higher Education - Grants', NULL, 'SOME UNIVERSITY', NULL,
                     'US DEPARTMENT OF AGRICULTURE AGRICULTURAL MARKETING SERVICE', 'Y'),
                (9,  'NSF',         '47.041', 'X8', NULL, NULL, NULL, NULL, NULL, NULL),
                (10, 'AID-FT',      NULL,     'X9', NULL, NULL, NULL, NULL, 'U S AGENCY FOR INTERNATIONAL DEVELOPMENT', 'Y'),
                (11, 'DOE',         '81.049', 'X10', NULL, NULL, NULL, NULL, NULL, NULL),
                (12, 'NIH-ALN',     '93.847', 'X11', NULL, NULL, NULL, NULL, NULL, NULL),
                (13, 'NIH-FT',      '93.001', 'X12', NULL, NULL, NULL, NULL, 'NIH NATIONAL CANCER', 'Y'),
                (14, 'HHS',         '93.001', 'X13', NULL, NULL, NULL, NULL, NULL, NULL),
                (15, 'STATE',       NULL,     'X14', '04-State Govt Grants and Cooperative Agreements', NULL, NULL, NULL, NULL, 'N'),
                (16, 'STATE-FED-FT', NULL,    'X15', '04-State Govt Grants and Cooperative Agreements', NULL, NULL, NULL, 'SOME AGENCY', 'Y'),
                (17, 'FEDERAL',     NULL,     'X16', '01-Federal Grants and Cooperative Agreement', NULL, NULL, NULL, NULL, NULL),
                (18, 'INDUSTRY',    NULL,     'X17', '10-Business Profit Contracts', NULL, NULL, NULL, NULL, NULL),
                (19, 'FFT',         NULL,     'X18', '27-Non-Profit - FFT - Grants', NULL, NULL, NULL, NULL, NULL);
            """);

        var sfns = (await connection.QueryAsync<(string ProjectNumber, string? PgmSfn)>(
            "SELECT [ProjectNumber], [PgmSfn] FROM [data].[v_PgmProjectSfnBuckets]"))
            .ToDictionary(row => row.ProjectNumber, row => row.PgmSfn);

        sfns["HATCH-AWD"].Should().Be("201");
        sfns["HATCH-DESC"].Should().Be("201");
        sfns["MS-DESC"].Should().Be("202");
        sfns["HATCH-ALN"].Should().BeNull("the NIFA project list decides 201 vs 202");
        sfns["NIFA-FT"].Should().Be("204", "a NIFA flow-through sponsor wins over the 10.x rule");
        sfns["NIFA-SPONSOR"].Should().Be("204");
        sfns["NIFA-ALN-NO-SPONSOR"].Should().Be("204", "a NIFA program ALN counts as NIFA");
        sfns["USDA-ALN"].Should().Be("219", "a non-NIFA USDA ALN stays 219");
        sfns["USDA-FT"].Should().Be("219");
        sfns["NSF"].Should().Be("209");
        sfns["AID-FT"].Should().Be("308");
        sfns["DOE"].Should().Be("310");
        sfns["NIH-ALN"].Should().Be("316");
        sfns["NIH-FT"].Should().Be("316");
        sfns["HHS"].Should().Be("313");
        sfns["STATE"].Should().Be("223");
        sfns["STATE-FED-FT"].Should().BeNull("federal flow-through keeps a state award off 223");
        sfns["FEDERAL"].Should().Be("318");
        sfns["INDUSTRY"].Should().Be("222");
        sfns["FFT"].Should().BeNull();
    }
}
