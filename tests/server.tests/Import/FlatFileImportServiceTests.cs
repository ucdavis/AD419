using ClosedXML.Excel;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Import;

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
    public async Task Import_logs_compact_validation_payload_without_row_values()
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
        var log = db.ImportLogs.Single(item => item.Id == validation.ImportLogId);
        log.ErrorPayload.Should().NotBeNull();
        log.ErrorPayload.Should().Contain("\"RowCount\":2");
        log.ErrorPayload.Should().Contain("\"RowsWithErrors\":2");
        log.ErrorPayload.Should().Contain("\"SampleRows\"");
        log.ErrorPayload.Should().Contain("duplicate_key");
        log.ErrorPayload.Should().NotContain("\"Values\"");
        log.ErrorPayload.Should().NotContain("Path Person");
        log.ErrorPayload.Should().NotContain("Second Person");
    }

    private static FlatFileImportService CreateService(Server.Core.Data.AppDbContext db)
    {
        return new FlatFileImportService(
            db,
            new FlatFileImportRegistry(),
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
