using Dapper;
using FluentAssertions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Server.Core.Data;
using Server.Models;
using Server.ProjectList;
using Server.Tests.SqlIntegration;

namespace Server.Tests.ProjectList;

[Trait("Category", "SqlIntegration")]
[Collection(SqlIntegrationCollection.Name)]
public sealed class ProjectListSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Project_list_queries_return_statuses_excluded_rows_and_candidates_from_seeded_data()
    {
        await fixture.ClearDataTablesAsync();
        await SeedProjectListScenarioAsync();

        await using var db = fixture.CreateDataDbContext();
        var service = new ProjectListService(db, Configuration());
        var cycle = Cycle();

        var response = await service.GetAsync(cycle, CancellationToken.None);

        response.Rows.Should().HaveCount(4);
        response.ExcludedRows.Should().ContainSingle(row => row.Accession == "A000005");
        response.Counts.Clean.Should().Be(1);
        response.Counts.Issues.Should().Be(3);
        response.Rows.Should().Contain(row => row.Accession == "A000001" && row.Status == "Clean" && row.Ae == "AE-CLEAN");
        response.Rows.Should().Contain(row => row.Accession == "A000002" && row.Status == "Not in All Projects");
        response.Rows.Should().Contain(row => row.Accession == "A000003" && row.Status == "No PGM match");
        response.Rows.Should().Contain(row => row.Accession == "A000004" && row.Status == "SFN mismatch");

        var allProjectCandidates = await service.GetAllProjectCandidatesAsync(
            cycle,
            "A000002",
            "Missing",
            CancellationToken.None);
        allProjectCandidates.Should().ContainSingle(candidate => candidate.ProjectNumber == "MISSING-ALT");

        var pgmCandidates = await service.GetPgmAwardCandidatesAsync(
            cycle,
            "A000003",
            "AWARD1",
            CancellationToken.None);
        pgmCandidates.Should().ContainSingle(candidate =>
            candidate.AwardKey == "AWARD1" &&
            candidate.PgmSfnBucket == "HATCH" &&
            candidate.ProjectNumbers == "AE-CLEAN");

        var sfnCandidates = await service.GetSfnCandidatesAsync(cycle, "A000004", CancellationToken.None);
        sfnCandidates.Should().Contain(candidate =>
            candidate.Sfn == "205" &&
            candidate.IsRecommended &&
            candidate.Source == "NIFA project suffix");

        var cleanSfnCandidates = await service.GetSfnCandidatesAsync(cycle, "A000001", CancellationToken.None);
        cleanSfnCandidates.Should().Contain(candidate =>
            candidate.Sfn == "201" &&
            candidate.IsRecommended &&
            candidate.Source == "NIFA project suffix, PGM master data");
    }

    private async Task SeedProjectListScenarioAsync()
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.OpenAsync();

        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[Sfns] ([Sfn], [Label])
            VALUES ('201', 'Hatch'), ('204', 'NIFA Competitive'), ('205', 'Animal Health');

            INSERT INTO [data].[AssistanceListingNumbers] ([ProgramNumber], [FederalAgency030])
            VALUES ('10.203', 'NATIONAL INSTITUTE OF FOOD AND AGRICULTURE');

            INSERT INTO [data].[ActiveProjects]
                ([ProjectNumber], [AccessionNumber], [UcpEmployeeId], [UcPathName], [Is204], [ExcludeFromUi],
                 [Notes], [ProjectDirector], [PdEmailAddress])
            VALUES
                ('CLEAN-H',   'A000001', '10000001', 'Clean Person', 0, 0, NULL, 'Clean PI', 'clean@example.test'),
                ('MISSING-H', 'A000002', '10000002', 'Missing Person', 0, 0, NULL, 'Missing PI', 'missing@example.test'),
                ('COMP-CG',   'A000003', '10000003', 'Comp Person', 1, 0, NULL, 'Comp PI', 'comp@example.test'),
                ('MISM-AH',   'A000004', '10000004', 'Mismatch Person', 0, 0, NULL, 'Mismatch PI', 'mismatch@example.test'),
                ('EXCL-H',    'A000005', '10000005', 'Excluded Person', 0, 1, 'Resolved elsewhere', 'Excluded PI', 'excluded@example.test');

            INSERT INTO [data].[AllProjects]
                ([AccessionNumber], [ProjectNumber], [AwardNumber], [AwardKey], [Title], [OrganizationName],
                 [Department], [ProjectDirector], [FundingSource], [DocumentType], [ProjectStatus], [Source],
                 [ProjectStartDate], [ProjectEndDate])
            VALUES
                ('A000001', 'CLEAN-H',   'AWD-1', 'AWARD1', 'Clean Hatch Project', 'CAES', 'Plant Sciences', 'All PI 1', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30'),
                ('A000001', 'CLEAN-H',   'AWD-1', 'AWARD1', 'Duplicate Clean Hatch Project', 'CAES', 'Plant Sciences', 'All PI 2', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30'),
                ('A000002', 'MISSING-H', 'AWD-2', 'AWARD2', 'Missing Candidate', 'CAES', 'Animal Science', 'All PI 3', 'NIFA', 'Project', 'Active', 'NIF', '2026-10-01', '2027-09-30'),
                ('A999999', 'MISSING-ALT', 'AWD-ALT', 'AWARDALT', 'Missing Candidate Alternative', 'CAES', 'Animal Science', 'All PI 7', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30'),
                ('A000003', 'COMP-CG',   'AWD-3', 'AWARD3', 'Competitive Project', 'CAES', 'Food Science', 'All PI 4', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30'),
                ('A000004', 'MISM-AH',   'AWD-4', 'AWARD4', 'Mismatch Project', 'CAES', 'Vet Med', 'All PI 5', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30'),
                ('A000005', 'EXCL-H',    'AWD-5', 'AWARD5', 'Excluded Project', 'CAES', 'Viticulture', 'All PI 6', 'NIFA', 'Project', 'Active', 'NIF', '2024-10-01', '2025-09-30');

            INSERT INTO [data].[PGMProjects]
                ([ProjectId], [ProjectNumber], [AwardName], [SponsorAwardNumber], [SponsorAwardKey],
                 [CfdaProgramNumber], [PrincipalInvestigatorNames])
            VALUES
                (1001, 'AE-CLEAN',    'Clean Award',    'AWARD-1', 'AWARD1', '10.203', 'Clean PI'),
                (1004, 'AE-MISMATCH', 'Mismatch Award', 'AWARD-4', 'AWARD4', '10.203', 'Mismatch PI');
            """);
    }

    private static FiscalYearCycle Cycle()
    {
        FiscalYearCycle.TryParse("FY25", out var cycle).Should().BeTrue();
        return cycle!;
    }

    private IConfiguration Configuration() =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DataConnection"] = fixture.ConnectionString,
            })
            .Build();
}
