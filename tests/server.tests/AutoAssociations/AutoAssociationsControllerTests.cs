using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.AutoAssociations;
using Server.Controllers;
using Server.Core.Domain;
using Server.Models.AutoAssociations;

namespace Server.Tests.AutoAssociations;

public class AutoAssociationsControllerTests
{
    [Fact]
    public async Task Every_report_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        var service = new StubReportService();
        var controller = new AutoAssociationsController(service, db);

        (await controller.Build(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule204(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule20x(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.Rule220(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.ExcludedProjects(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.FteOverOne(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        (await controller.PreAssociationTotals(CancellationToken.None)).Should().BeOfType<ConflictObjectResult>();
        service.Calls.Should().Be(0);
    }

    [Fact]
    public async Task Build_wraps_a_null_build_in_the_cycle_envelope()
    {
        await using var db = TestDbContextFactory.CreateInMemory();
        db.WorkflowRuns.Add(new WorkflowRun
        {
            FiscalYear = "FY25",
            CycleStart = new DateOnly(2024, 10, 1),
            CycleEnd = new DateOnly(2025, 9, 30),
            IsCurrent = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        var service = new StubReportService();
        var controller = new AutoAssociationsController(service, db);

        var result = await controller.Build(CancellationToken.None);

        var ok = result.Should().BeOfType<OkObjectResult>().Subject;
        var response = ok.Value.Should().BeOfType<AutoAssociationReportResponse<AutoAssociationBuildDto?>>().Subject;
        response.FiscalYear.Should().Be("FY25");
        response.CycleStart.Should().Be(new DateOnly(2024, 10, 1));
        response.Data.Should().BeNull();
        service.Calls.Should().Be(1);
    }

    private sealed class StubReportService : IAutoAssociationReportService
    {
        public int Calls { get; private set; }

        public Task<AutoAssociationBuildDto?> GetBuildAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<AutoAssociationBuildDto?>(null);
        }

        public Task<Rule204ReportDto> GetRule204Async(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule204ReportDto([], [], []));
        }

        public Task<Rule20xReportDto> GetRule20xAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule20xReportDto([], []));
        }

        public Task<Rule220ReportDto> GetRule220Async(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new Rule220ReportDto([], []));
        }

        public Task<IReadOnlyList<ExcludedProjectDto>> GetExcludedProjectsAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<ExcludedProjectDto>>([]);
        }

        public Task<IReadOnlyList<FteOverOneDto>> GetFteOverOneAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<FteOverOneDto>>([]);
        }

        public Task<IReadOnlyList<PreAssociationTotalDto>> GetPreAssociationTotalsAsync(CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<PreAssociationTotalDto>>([]);
        }
    }
}
