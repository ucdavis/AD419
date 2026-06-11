using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Core.Import;

namespace Server.Tests.Import;

public class PgmProjectsControllerTests
{
    [Fact]
    public async Task Import_returns_bad_request_when_report_date_is_missing()
    {
        var importService = new FakeImportService();
        var controller = new PgmProjectsController(importService);

        var result = await controller.Import(null, CancellationToken.None);

        result.Result.Should().BeOfType<BadRequestObjectResult>();
        importService.Invocations.Should().BeEmpty();
    }

    [Fact]
    public async Task Import_runs_the_import_for_the_given_report_date()
    {
        var importService = new FakeImportService();
        var controller = new PgmProjectsController(importService);
        var reportDate = new DateOnly(2026, 6, 30);

        var result = await controller.Import(reportDate, CancellationToken.None);

        importService.Invocations.Should().Equal(reportDate);
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeEquivalentTo(new PgmProjectsImportResult(42, reportDate));
    }

    private sealed class FakeImportService : IPgmProjectsImportService
    {
        public List<DateOnly> Invocations { get; } = [];

        public Task<PgmProjectsImportResult> ImportAsync(DateOnly reportDate, CancellationToken cancellationToken = default)
        {
            Invocations.Add(reportDate);
            return Task.FromResult(new PgmProjectsImportResult(42, reportDate));
        }
    }
}
