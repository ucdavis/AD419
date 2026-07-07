using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Domain;
using Server.Import;
using Server.Models.Imports;

namespace Server.Tests.Controllers;

public class ImportsControllerTests
{
    [Fact]
    public async Task Recent_returns_latest_import_for_each_dataset()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var completedAt = DateTimeOffset.Parse("2026-06-17T12:00:00Z");

        for (var index = 0; index < 30; index++)
        {
            db.ImportLogs.Add(new ImportLog
            {
                Dataset = "all-projects",
                Filename = $"all-projects-{index}.csv",
                Status = "Succeeded",
                AttemptedRows = index,
                RowsImported = index,
                StartedAt = completedAt.AddMinutes(index).AddSeconds(-30),
                CompletedAt = completedAt.AddMinutes(index),
            });
        }

        db.ImportLogs.Add(new ImportLog
        {
            Dataset = "active-projects",
            Filename = "active-projects.csv",
            Status = "Succeeded",
            AttemptedRows = 1,
            RowsImported = 1,
            StartedAt = completedAt.AddMinutes(-10),
            CompletedAt = completedAt.AddMinutes(-9),
        });
        await db.SaveChangesAsync();

        var controller = new ImportsController(
            new NoOpFlatFileImportService(),
            new FlatFileImportRegistry(),
            db);

        var result = await controller.Recent(CancellationToken.None);

        var ok = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        var summaries = ok.Value.Should()
            .BeAssignableTo<IReadOnlyList<ImportDatasetSummaryResponse>>()
            .Subject;

        var allProjects = summaries.Single(summary => summary.Dataset == "all-projects");
        var activeProjects = summaries.Single(summary => summary.Dataset == "active-projects");
        var assistanceListingNumbers = summaries.Single(summary =>
            summary.Dataset == "assistance-listing-numbers");

        allProjects.LastImport.Should().NotBeNull();
        allProjects.LastImport!.Filename.Should().Be("all-projects-29.csv");
        activeProjects.LastImport.Should().NotBeNull();
        activeProjects.LastImport!.Filename.Should().Be("active-projects.csv");
        assistanceListingNumbers.LastImport.Should().BeNull();
    }

    private sealed class NoOpFlatFileImportService : IFlatFileImportService
    {
        public Task<ImportResult> ImportAsync(
            string datasetId,
            IFormFile? file,
            System.Security.Claims.ClaimsPrincipal? user,
            CancellationToken cancellationToken)
        {
            throw new NotSupportedException();
        }
    }
}
