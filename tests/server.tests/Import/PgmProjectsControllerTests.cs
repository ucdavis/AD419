using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Server.Controllers;
using Server.Core.Import;
using Server.Models.ProjectIdentification;
using Server.ProjectIdentification;
using System.Security.Claims;

namespace Server.Tests.Import;

public class PgmProjectsControllerTests
{
    [Fact]
    public async Task Import_returns_bad_request_when_report_date_is_missing()
    {
        var importService = new FakeImportService();
        var projectIdentificationService = new FakeProjectIdentificationService();
        var controller = new PgmProjectsController(
            importService,
            projectIdentificationService,
            NullLogger<PgmProjectsController>.Instance);

        var result = await controller.Import(null, CancellationToken.None);

        result.Result.Should().BeOfType<BadRequestObjectResult>();
        importService.Invocations.Should().BeEmpty();
        projectIdentificationService.RecordedResults.Should().BeEmpty();
    }

    [Fact]
    public async Task Import_runs_the_import_for_the_given_report_date()
    {
        var importService = new FakeImportService();
        var projectIdentificationService = new FakeProjectIdentificationService();
        var controller = new PgmProjectsController(
            importService,
            projectIdentificationService,
            NullLogger<PgmProjectsController>.Instance);
        var reportDate = new DateOnly(2026, 6, 30);

        var result = await controller.Import(reportDate, CancellationToken.None);

        importService.Invocations.Should().Equal(reportDate);
        projectIdentificationService.RecordedResults.Should().Equal(new PgmProjectsImportResult(42, reportDate));
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeEquivalentTo(new PgmProjectsImportResult(42, reportDate));
    }

    [Fact]
    public async Task Import_returns_ok_when_workflow_recording_fails_after_import_succeeds()
    {
        var importService = new FakeImportService();
        var projectIdentificationService = new FakeProjectIdentificationService
        {
            ThrowOnRecord = true,
        };
        var controller = new PgmProjectsController(
            importService,
            projectIdentificationService,
            NullLogger<PgmProjectsController>.Instance);
        var reportDate = new DateOnly(2026, 6, 30);

        var result = await controller.Import(reportDate, CancellationToken.None);

        importService.Invocations.Should().Equal(reportDate);
        projectIdentificationService.RecordedResults.Should().Equal(new PgmProjectsImportResult(42, reportDate));
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

    private sealed class FakeProjectIdentificationService : IProjectIdentificationService
    {
        public List<PgmProjectsImportResult> RecordedResults { get; } = [];
        public bool ThrowOnRecord { get; init; }

        public Task<ProjectIdentificationSetupResponse> GetSetupAsync(
            ClaimsPrincipal user,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<ProjectIdentificationSetupResponse?> ConfirmFiscalPeriodAsync(
            string? fiscalYear,
            ClaimsPrincipal user,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<ProjectIdentificationSetupResponse?> SetChecklistItemCompletionAsync(
            string itemId,
            bool completed,
            ClaimsPrincipal user,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<ProjectIdentificationSetupResponse?> FinalizeProjectsAsync(
            ClaimsPrincipal user,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task RecordPgmImportAsync(
            PgmProjectsImportResult result,
            ClaimsPrincipal user,
            CancellationToken cancellationToken)
        {
            RecordedResults.Add(result);
            if (ThrowOnRecord)
            {
                throw new InvalidOperationException("Workflow recording failed.");
            }

            return Task.CompletedTask;
        }
    }
}
