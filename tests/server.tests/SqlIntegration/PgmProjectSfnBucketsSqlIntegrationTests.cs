using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;

namespace Server.Tests.SqlIntegration;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class PgmProjectSfnBucketsSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task PgmSfn_maps_nifa_buckets_and_non_nifa_federal_aln_prefixes()
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
                ('47.041', 'NATIONAL SCIENCE FOUNDATION'),
                ('10.001', 'AGRICULTURAL RESEARCH SERVICE, AGRICULTURE, DEPARTMENT OF'),
                ('93.001', 'HEALTH AND HUMAN SERVICES, DEPARTMENT OF');

            INSERT INTO [data].[PGMProjects] ([ProjectId], [ProjectNumber], [CfdaProgramNumber], [SponsorAwardKey])
            VALUES
                (1, 'P-HATCH',   '10.203', 'AWD1'),
                (2, 'P-MCS',     '10.202', 'AWD2'),
                (3, 'P-AH',      '10.205', 'AWD3'),
                (4, 'P-NIFA',    '10.310', 'AWD4'),
                (5, 'P-NSF',     '47.041', 'AWD5'),
                (6, 'P-USDA',    '10.001', 'AWD6'),
                (7, 'P-OTHER',   '93.001', 'AWD7'),
                (8, 'P-NOMATCH', '99.999', 'AWD8'),
                (9, 'P-NOALN',   NULL,     'AWD9');
            """);

        var rows = (await connection.QueryAsync<BucketRow>(
            """
            SELECT [ProjectNumber], [PgmSfnBucket], [PgmSfn]
            FROM [data].[v_PgmProjectSfnBuckets]
            """)).ToDictionary(row => row.ProjectNumber);

        rows["P-HATCH"].Should().BeEquivalentTo(new BucketRow("P-HATCH", "HATCH", null));
        rows["P-MCS"].Should().BeEquivalentTo(new BucketRow("P-MCS", "203", "203"));
        rows["P-AH"].Should().BeEquivalentTo(new BucketRow("P-AH", "205", "205"));
        rows["P-NIFA"].Should().BeEquivalentTo(new BucketRow("P-NIFA", "204", "204"));
        rows["P-NSF"].Should().BeEquivalentTo(new BucketRow("P-NSF", "NON-NIFA", "209"));
        rows["P-USDA"].Should().BeEquivalentTo(new BucketRow("P-USDA", "NON-NIFA", "219"));
        rows["P-OTHER"].Should().BeEquivalentTo(new BucketRow("P-OTHER", "NON-NIFA", null));
        rows["P-NOMATCH"].Should().BeEquivalentTo(new BucketRow("P-NOMATCH", null, null));
        rows["P-NOALN"].Should().BeEquivalentTo(new BucketRow("P-NOALN", null, null));
    }

    private sealed record BucketRow(string ProjectNumber, string? PgmSfnBucket, string? PgmSfn);
}
