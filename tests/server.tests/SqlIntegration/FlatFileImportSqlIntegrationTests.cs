using Dapper;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Import;

namespace Server.Tests.SqlIntegration;

[Collection(SqlIntegrationCollection.Name)]
public sealed class FlatFileImportSqlIntegrationTests(SqlServerDataDbFixture fixture)
{
    [Fact]
    public async Task Ce_specialists_import_accepts_active_accessions_and_transactionally_replaces_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedActiveProjectsAsync("1111111", "2222222");

        await using var appDb = TestDbContextFactory.CreateInMemory();
        await using var dataDb = fixture.CreateDataDbContext();
        var service = CreateService(appDb, dataDb);

        var firstResult = await service.ImportAsync(
            "ce-specialists",
            CreateCeCsv("1111111", "127,900.00", "0.123456", "0.654321"),
            null,
            CancellationToken.None);

        firstResult.Should().BeOfType<ImportSucceeded>();

        var secondResult = await service.ImportAsync(
            "ce-specialists",
            CreateCeCsv("2222222", "140,000.25", "0.200000", "0.750000"),
            null,
            CancellationToken.None);

        secondResult.Should().BeOfType<ImportSucceeded>();

        await using var connection = new SqlConnection(fixture.ConnectionString);
        var rows = (await connection.QueryAsync<CeSpecialistRow>(
            """
            SELECT [ProjectAccessionNum], [PercentCeEffort], [FullAnnualPayRate], [FTE],
                   [Exp SFN] AS [ExpSfn], [FTE SFN] AS [FteSfn]
            FROM [data].[ad419_CESpecialists];
            """)).ToList();

        rows.Should().ContainSingle();
        rows[0].ProjectAccessionNum.Should().Be("2222222");
        rows[0].PercentCeEffort.Should().Be(0.200000m);
        rows[0].FullAnnualPayRate.Should().Be(140000.25m);
        rows[0].Fte.Should().Be(0.750000m);
        rows[0].ExpSfn.Should().Be("241");
        rows[0].FteSfn.Should().Be("242");
    }

    [Fact]
    public async Task Field_station_import_reports_each_unmatched_accession_and_preserves_existing_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedActiveProjectsAsync("1111111");

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ad419_FieldStationExpenses]
                ([ProjectAccessionNum], [ProjectDirector], [FieldStationCharge])
            VALUES (N'1111111', N'Existing Director', 25.5000);
            """);

        await using var appDb = TestDbContextFactory.CreateInMemory();
        await using var dataDb = fixture.CreateDataDbContext();
        var service = CreateService(appDb, dataDb);
        var file = CreateCsvFile(
            "field-station.csv",
            ["ProjectAccessionNum", "ProjectDirector", "FieldStationCharge"],
            [
                ["9999998", "Missing One", "100.0000"],
                ["9999999", "Missing Two", "200.0000"],
            ]);

        var result = await service.ImportAsync(
            "field-station-expenses",
            file,
            null,
            CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.Rows.Should().HaveCount(2);
        validation.Rows.Should().OnlyContain(row =>
            row.Errors.Count == 1 && row.Errors[0].Contains("was not found in the active project list", StringComparison.Ordinal));

        var existing = await connection.QuerySingleAsync<FieldStationRow>(
            """
            SELECT [ProjectAccessionNum], [ProjectDirector], [FieldStationCharge]
            FROM [data].[ad419_FieldStationExpenses];
            """);
        existing.ProjectAccessionNum.Should().Be("1111111");
        existing.ProjectDirector.Should().Be("Existing Director");
        existing.FieldStationCharge.Should().Be(25.5000m);
    }

    [Fact]
    public async Task Field_station_import_rejects_duplicate_accessions_and_preserves_existing_rows()
    {
        await fixture.ClearDataTablesAsync();
        await SeedActiveProjectsAsync("1111111");

        await using var connection = new SqlConnection(fixture.ConnectionString);
        await connection.ExecuteAsync(
            """
            INSERT INTO [data].[ad419_FieldStationExpenses]
                ([ProjectAccessionNum], [ProjectDirector], [FieldStationCharge])
            VALUES (N'1111111', N'Existing Director', 25.5000);
            """);

        await using var appDb = TestDbContextFactory.CreateInMemory();
        await using var dataDb = fixture.CreateDataDbContext();
        var service = CreateService(appDb, dataDb);
        var file = CreateCsvFile(
            "field-station.csv",
            ["ProjectAccessionNum", "ProjectDirector", "FieldStationCharge"],
            [
                ["1111111", "First", "100.0000"],
                ["1111111", "Second", "200.0000"],
            ]);

        var result = await service.ImportAsync(
            "field-station-expenses",
            file,
            null,
            CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.Rows.Should().OnlyContain(row =>
            row.CellErrors.Any(error => error.Code == "duplicate_key"));

        var rowCount = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM [data].[ad419_FieldStationExpenses];");
        rowCount.Should().Be(1);
    }

    private async Task SeedActiveProjectsAsync(params string[] accessions)
    {
        await using var connection = new SqlConnection(fixture.ConnectionString);
        foreach (var accession in accessions)
        {
            await connection.ExecuteAsync(
                """
                INSERT INTO [data].[ActiveProjects]
                    ([ProjectNumber], [AccessionNumber], [UcpEmployeeId], [UcPathName], [Is204],
                     [ProjectDirector], [PdEmailAddress])
                VALUES
                    (@ProjectNumber, @AccessionNumber, N'12345678', N'Test Person', 0,
                     N'Test Director', N'director@example.test');
                """,
                new
                {
                    ProjectNumber = $"PRJ-{accession}",
                    AccessionNumber = accession,
                });
        }
    }

    private static FlatFileImportService CreateService(
        Server.Core.Data.AppDbContext appDb,
        Server.Core.Data.DataDbContext dataDb)
    {
        return new FlatFileImportService(
            appDb,
            dataDb,
            new FlatFileImportRegistry(),
            new ConfigurationBuilder().Build(),
            NullLogger<FlatFileImportService>.Instance);
    }

    private static IFormFile CreateCeCsv(
        string accession,
        string payRate,
        string percentCeEffort,
        string fte)
    {
        return CreateCsvFile(
            "ce-specialists.csv",
            [
                "Dept code",
                "Dept Name",
                "PI",
                "DeptLevelOrg",
                "EmployeeID",
                "ProjectAccessionNum",
                "ProjectNumber",
                "PercentCeEffort",
                "FullAnnualPayRate",
                "TitleCode",
                "FTE",
                "Entity",
                "EXP SFN",
                "FTE SFN",
            ],
            [["ABC123", "Department", "Director", "ORG", "12345678", accession, $"PRJ-{accession}", percentCeEffort, payRate, "1234", fte, "UCD", "241", "242"]]);
    }

    private static IFormFile CreateCsvFile(string filename, string[] headers, string[][] rows)
    {
        var lines = new List<string>
        {
            string.Join(",", headers.Select(EscapeCsvValue)),
        };
        lines.AddRange(rows.Select(row => string.Join(",", row.Select(EscapeCsvValue))));
        var contents = string.Join(Environment.NewLine, lines);
        var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(contents));
        return new FormFile(stream, 0, stream.Length, "file", filename);
    }

    private static string EscapeCsvValue(string value)
    {
        return value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r')
            ? $"\"{value.Replace("\"", "\"\"")}\""
            : value;
    }

    private sealed class CeSpecialistRow
    {
        public string ProjectAccessionNum { get; init; } = string.Empty;
        public decimal PercentCeEffort { get; init; }
        public decimal FullAnnualPayRate { get; init; }
        public decimal Fte { get; init; }
        public string ExpSfn { get; init; } = string.Empty;
        public string FteSfn { get; init; } = string.Empty;
    }

    private sealed class FieldStationRow
    {
        public string ProjectAccessionNum { get; init; } = string.Empty;
        public string? ProjectDirector { get; init; }
        public decimal FieldStationCharge { get; init; }
    }
}
