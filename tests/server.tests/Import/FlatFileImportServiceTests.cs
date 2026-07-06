using ClosedXML.Excel;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Import;
using Server.Models.Imports;
using System.Text.Json;

namespace Server.Tests.Import;

public class FlatFileImportServiceTests
{
    [Theory]
    [InlineData("Accession Number", "AccessionNumber")]
    [InlineData("accession-number", "AccessionNumber")]
    [InlineData("Project Director Email", "ProjectDirectorEmail")]
    public void Registry_normalizes_known_headers(string sourceHeader, string expectedTargetColumn)
    {
        var registry = new FlatFileImportRegistry();
        var dataset = registry.Find("all-projects");

        var column = dataset?.FindColumnBySourceHeader(sourceHeader);

        column.Should().NotBeNull();
        column!.TargetColumn.Should().Be(expectedTargetColumn);
    }

    [Fact]
    public void Dataset_definition_rejects_normalized_header_collisions_between_columns()
    {
        var act = () => new ImportDatasetDefinition(
            "test",
            "Test",
            "data",
            "Test",
            [
                new ImportColumn("ProjectId", ImportColumnType.String, true, null, ["Project ID"]),
                new ImportColumn("ProjectID", ImportColumnType.String, true, null, []),
            ],
            []);

        act.Should()
            .Throw<InvalidOperationException>()
            .WithMessage("*ProjectID*Project ID*ProjectId*");
    }

    [Fact]
    public void Dataset_definition_allows_normalized_aliases_for_the_same_column()
    {
        var dataset = new ImportDatasetDefinition(
            "test",
            "Test",
            "data",
            "Test",
            [
                new ImportColumn("ProjectID", ImportColumnType.String, true, null, ["Project ID"]),
            ],
            []);

        dataset.FindColumnBySourceHeader("Project ID")?.TargetColumn.Should().Be("ProjectID");
        dataset.FindColumnBySourceHeader("ProjectID")?.TargetColumn.Should().Be("ProjectID");
    }

    [Fact]
    public async Task Import_rejects_unsupported_file_types()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateTextFile("projects.txt", "not,a,supported,type");

        var result = await service.ImportAsync("all-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "invalid_file_type");
        validation.AttemptedRows.Should().Be(0);
        validation.ImportLogId.Should().NotBeNull();
        db.ImportLogs.Should().ContainSingle(log =>
            log.Id == validation.ImportLogId &&
            log.Dataset == "all-projects" &&
            log.Status == "ValidationFailed");
    }

    [Fact]
    public async Task Import_reports_malformed_workbooks_as_validation_failures()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateTextFile("active-projects.xlsx", "not a workbook");

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().ContainSingle(error => error.Code == "invalid_workbook");
        validation.AttemptedRows.Should().Be(0);
        validation.ImportLogId.Should().NotBeNull();
        db.ImportLogs.Should().ContainSingle(log =>
            log.Id == validation.ImportLogId &&
            log.Dataset == "active-projects" &&
            log.Status == "ValidationFailed");
    }

    [Fact]
    public async Task Import_reports_missing_required_headers()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateWorkbook("all-projects.xlsx",
            ["Accession Number"],
            [["A123"]]);

        var result = await service.ImportAsync("all-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error =>
            error.Code == "missing_required_header" && error.TargetColumn == "OrganizationName");
    }

    [Fact]
    public async Task Import_rejects_flat_files_without_data_rows()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateWorkbook("active-projects.xlsx",
            [
                "Project Number",
                "Accession Number",
                "UCP Employee ID",
                "UCPath Name",
                "Is 204",
                "Project Director",
                "PD Email Address",
            ],
            []);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "no_data_rows");
        validation.AttemptedRows.Should().Be(0);
    }

    [Fact]
    public async Task Import_collects_csv_required_type_length_and_duplicate_errors_before_persistence()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateCsvFile("active-projects.csv",
            [
                "Project Number",
                "Accession Number",
                "UCP Employee ID",
                "UCPath Name",
                "Is 204",
                "Project Director",
                "PD Email Address",
            ],
            [
                ["PRJ-1", "1234567", "00000001", "Path Person", "maybe", "Director", "pd@example.com"],
                ["PRJ-1", "123456789", "", "Second Person", "yes", "Director", "pd2@example.com"],
            ]);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.AttemptedRows.Should().Be(2);
        validation.Rows[0].CellErrors.Should().Contain(error =>
            error.TargetColumn == "Is204" && error.Code == "type_conversion");
        validation.Rows[0].CellErrors.Should().Contain(error =>
            error.TargetColumn == "ProjectNumber" &&
            error.SourceHeader == "Project Number" &&
            error.RawValue == "PRJ-1" &&
            error.Code == "duplicate_key" &&
            error.Message.Contains("Project Number", StringComparison.Ordinal));
        validation.Rows[1].CellErrors.Should().Contain(error =>
            error.TargetColumn == "AccessionNumber" && error.Code == "max_length");
        validation.Rows[1].CellErrors.Should().Contain(error =>
            error.TargetColumn == "UcpEmployeeId" && error.Code == "required");
        validation.Rows[1].CellErrors.Should().Contain(error =>
            error.TargetColumn == "ProjectNumber" &&
            error.SourceHeader == "Project Number" &&
            error.RawValue == "PRJ-1" &&
            error.Code == "duplicate_key" &&
            error.Message.Contains("Project Number", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Import_all_projects_allows_duplicate_accession_numbers_and_project_numbers()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateCsvFile("all-projects.csv",
            AllProjectsHeaders(),
            [
                ["A-1", "PRJ-1", "", "Org", "Director", "Federal", "Initial", "Active", "NIF"],
                ["A-1", "PRJ-1", "", "Org", "Director", "Federal", "Initial", "Active", "NIF"],
            ]);

        var result = await service.ImportAsync("all-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "database_validation_failed");
        validation.AttemptedRows.Should().Be(2);
        validation.Rows.Should().OnlyContain(row =>
            row.CellErrors.All(error => error.Code != "duplicate_key"));
    }

    [Fact]
    public async Task Import_all_projects_still_rejects_duplicate_source_and_proposal_numbers()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateCsvFile("all-projects.csv",
            AllProjectsHeaders(),
            [
                ["A-1", "PRJ-1", "P-1", "Org", "Director", "Federal", "Initial", "Active", "NIF"],
                ["A-2", "PRJ-2", "P-1", "Org", "Director", "Federal", "Initial", "Active", "NIF"],
            ]);

        var result = await service.ImportAsync("all-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.AttemptedRows.Should().Be(2);
        validation.FileErrors.Should().BeEmpty();
        validation.Rows.Should().OnlyContain(row =>
            row.CellErrors.Any(error =>
                error.Code == "duplicate_key" &&
                error.Message.Contains("Source and Proposal Number", StringComparison.Ordinal)));
    }

    [Fact]
    public async Task Import_assistance_listing_numbers_allows_loosened_program_number_and_text_values()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var longValue = new string('X', 501);
        var file = CreateCsvFile("assistance-listing-numbers.csv",
            [
                "Program Title",
                "Program Number",
                "Popular Name 020",
                "Federal Agency 030",
                "Uses And Use Restrictions 070",
                "Published Date",
                "Recovery",
                "URL",
            ],
            [
                [longValue, "1234567", longValue, "Agency", new string('U', 51), "not a date", "maybe", "https://example.test/1"],
                [longValue, "1234567", longValue, "Agency", new string('U', 51), "still not a date", "not yes no", "https://example.test/2"],
                [longValue, "", longValue, "Agency", new string('U', 51), "", "", "https://example.test/3"],
            ]);

        var result = await service.ImportAsync("assistance-listing-numbers", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "database_validation_failed");
        validation.AttemptedRows.Should().Be(3);
        validation.Rows.Should().OnlyContain(row =>
            row.CellErrors.All(error =>
                error.Code != "required" &&
                error.Code != "max_length" &&
                error.Code != "type_conversion" &&
                error.Code != "duplicate_key"));
    }

    [Fact]
    public async Task Import_all_projects_still_rejects_overlong_strings()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateCsvFile("all-projects.csv",
            AllProjectsHeaders(),
            [
                ["A-1", "PRJ-1", "", "Org", "Director", "Federal", "DocumentTooLong", "Active", "NIF"],
            ]);

        var result = await service.ImportAsync("all-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.Rows.Should().ContainSingle();
        validation.Rows[0].CellErrors.Should().Contain(error =>
            error.TargetColumn == "DocumentType" &&
            error.Code == "max_length");
    }

    [Fact]
    public async Task Import_preserves_flat_file_column_order_in_validation_values()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateCsvFile("active-projects.csv",
            [
                "PD Email Address",
                "Project Director",
                "Is 204",
                "UCPath Name",
                "UCP Employee ID",
                "Accession Number",
                "Project Number",
            ],
            [
                ["pd@example.com", "Director", "maybe", "Path Person", "00000001", "1234567", "PRJ-1"],
            ]);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.Rows.Should().ContainSingle();
        validation.Rows[0].Values.Keys.Should().Equal([
            "PdEmailAddress",
            "ProjectDirector",
            "Is204",
            "UcPathName",
            "UcpEmployeeId",
            "AccessionNumber",
            "ProjectNumber",
        ]);
    }

    [Fact]
    public async Task Import_reports_duplicate_headers_before_row_parsing()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateWorkbook("active-projects.xlsx",
            [
                "Project Number",
                "Project-Number",
                "Accession Number",
                "UCP Employee ID",
                "UCPath Name",
                "Is 204",
                "Project Director",
                "PD Email Address",
            ],
            [
                ["PRJ-1", "PRJ-1", "1234567", "00000001", "Path Person", "yes", "Director", "pd@example.com"],
            ]);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "duplicate_header");
        validation.Rows.Should().BeEmpty();
        validation.AttemptedRows.Should().Be(0);
    }

    [Fact]
    public async Task Import_logs_persistence_failures_without_marking_success()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateWorkbook("active-projects.xlsx",
            [
                "Project Number",
                "Accession Number",
                "UCP Employee ID",
                "UCPath Name",
                "Is 204",
                "Project Director",
                "PD Email Address",
            ],
            [
                ["PRJ-1", "1234567", "00000001", "Path Person", "yes", "Director", "pd@example.com"],
            ]);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        validation.FileErrors.Should().Contain(error => error.Code == "database_validation_failed");
        validation.AttemptedRows.Should().Be(1);
        validation.ImportLogId.Should().NotBeNull();
        db.ImportLogs.Should().ContainSingle(log =>
            log.Id == validation.ImportLogId &&
            log.Dataset == "active-projects" &&
            log.Status == "PersistenceFailed" &&
            log.AttemptedRows == 1 &&
            log.RowsImported == null &&
            log.ErrorPayload != null &&
            log.ErrorPayload.Contains("database_validation_failed", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Import_logs_all_validation_errors_without_row_values()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var rows = Enumerable.Range(1, 105)
            .Select(index => new[]
            {
                $"PRJ-{index}",
                index.ToString("D7"),
                index.ToString("D8"),
                $"Person {index}",
                "maybe",
                "Director",
                $"pd{index}@example.com",
            })
            .ToArray();
        var file = CreateCsvFile("active-projects.csv",
            [
                "Project Number",
                "Accession Number",
                "UCP Employee ID",
                "UCPath Name",
                "Is 204",
                "Project Director",
                "PD Email Address",
            ],
            rows);

        var result = await service.ImportAsync("active-projects", file, null, CancellationToken.None);

        var validation = result.Should().BeOfType<ImportValidationFailed>().Subject.Response;
        var log = db.ImportLogs.Single(item => item.Id == validation.ImportLogId);
        log.ErrorPayload.Should().NotBeNull();
        var payload = JsonSerializer.Deserialize<ImportValidationHistoryResponse>(log.ErrorPayload!);

        payload.Should().NotBeNull();
        payload!.RowCount.Should().Be(105);
        payload.RowsWithErrors.Should().Be(105);
        payload.Rows.Should().HaveCount(105);
        payload.ErrorCount.Should().Be(payload.Rows.Sum(row =>
            row.Errors.Count + row.CellErrors.Count));
        payload.ErrorCount.Should().BeGreaterThan(105);
        payload.Truncated.Should().BeFalse();
        payload.Rows.Should().OnlyContain(row =>
            row.CellErrors.Any(error => error.Code == "type_conversion"));
        log.ErrorPayload.Should().NotContain("\"Values\"");
        log.ErrorPayload.Should().NotContain("Person 1");
        log.ErrorPayload.Should().NotContain("Person 105");
    }

    private static string[] AllProjectsHeaders()
    {
        return
        [
            "Accession Number",
            "Project Number",
            "Proposal Number",
            "Organization Name",
            "Project Director",
            "Funding Source",
            "Document Type",
            "Project Status",
            "Source",
        ];
    }

    private static FlatFileImportService CreateService(Server.Core.Data.AppDbContext db)
    {
        return new FlatFileImportService(
            db,
            new FlatFileImportRegistry(),
            new Server.Core.Data.DataDatabaseTransactionFactory(db, new ConfigurationBuilder().Build()),
            NullLogger<FlatFileImportService>.Instance);
    }

    private static IFormFile CreateTextFile(string filename, string contents)
    {
        var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(contents));
        return new FormFile(stream, 0, stream.Length, "file", filename);
    }

    private static IFormFile CreateCsvFile(string filename, string[] headers, string[][] rows)
    {
        var lines = new List<string>
        {
            string.Join(",", headers.Select(EscapeCsvValue)),
        };
        lines.AddRange(rows.Select(row => string.Join(",", row.Select(EscapeCsvValue))));

        return CreateTextFile(filename, string.Join(Environment.NewLine, lines));
    }

    private static string EscapeCsvValue(string value)
    {
        return value.Contains(',') || value.Contains('"') || value.Contains('\n') || value.Contains('\r')
            ? $"\"{value.Replace("\"", "\"\"")}\""
            : value;
    }

    private static IFormFile CreateWorkbook(string filename, string[] headers, string[][] rows)
    {
        using var workbook = new XLWorkbook();
        var worksheet = workbook.Worksheets.Add("Import");

        for (var columnIndex = 0; columnIndex < headers.Length; columnIndex++)
        {
            worksheet.Cell(1, columnIndex + 1).Value = headers[columnIndex];
        }

        for (var rowIndex = 0; rowIndex < rows.Length; rowIndex++)
        {
            for (var columnIndex = 0; columnIndex < rows[rowIndex].Length; columnIndex++)
            {
                worksheet.Cell(rowIndex + 2, columnIndex + 1).Value = rows[rowIndex][columnIndex];
            }
        }

        var stream = new MemoryStream();
        workbook.SaveAs(stream);
        stream.Position = 0;
        return new FormFile(stream, 0, stream.Length, "file", filename);
    }
}
