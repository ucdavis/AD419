using ClosedXML.Excel;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Import;

namespace Server.Tests.Import;

public class SpreadsheetImportServiceTests
{
    [Theory]
    [InlineData("Accession Number", "AccessionNumber")]
    [InlineData("accession-number", "AccessionNumber")]
    [InlineData("Project Director Email", "ProjectDirectorEmail")]
    public void Registry_normalizes_known_headers(string sourceHeader, string expectedTargetColumn)
    {
        var registry = new SpreadsheetImportRegistry();
        var dataset = registry.Find("all-projects");

        var column = dataset?.FindColumnBySourceHeader(sourceHeader);

        column.Should().NotBeNull();
        column!.TargetColumn.Should().Be(expectedTargetColumn);
    }

    [Fact]
    public async Task Import_rejects_non_xlsx_files()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = CreateService(db);
        var file = CreateTextFile("projects.csv", "not,xlsx");

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
    public async Task Import_rejects_workbooks_without_data_rows()
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
    public async Task Import_collects_required_type_length_and_duplicate_errors_before_persistence()
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

    private static SpreadsheetImportService CreateService(Server.Core.Data.AppDbContext db)
    {
        return new SpreadsheetImportService(
            db,
            new SpreadsheetImportRegistry(),
            NullLogger<SpreadsheetImportService>.Instance);
    }

    private static IFormFile CreateTextFile(string filename, string contents)
    {
        var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(contents));
        return new FormFile(stream, 0, stream.Length, "file", filename);
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
