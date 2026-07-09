using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.Models;
using Server.Models.ProjectList;
using Server.ProjectList;

namespace Server.Tests.ProjectList;

public class ProjectListControllerTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("twenty-six")]
    [InlineData("FY10000")]
    public async Task Get_returns_bad_request_for_missing_or_invalid_fy(string? fy)
    {
        var controller = new ProjectListController(new StubProjectListService());

        var result = await controller.Get(fy, CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Get_passes_cycle_to_service_and_returns_response()
    {
        var service = new StubProjectListService();
        var controller = new ProjectListController(service);

        var result = await controller.Get("FY26", CancellationToken.None);

        var ok = result.Should().BeOfType<OkObjectResult>().Subject;
        ok.Value.Should().BeSameAs(service.Response);
        service.ReceivedCycle.Should().Be(new FiscalYearCycle(
            "FY26",
            new DateOnly(2025, 10, 1),
            new DateOnly(2026, 9, 30)));
    }

    private sealed class StubProjectListService : IProjectListService
    {
        public FiscalYearCycle? ReceivedCycle { get; private set; }

        public ProjectListResponse Response { get; } = new(
            "FY26",
            new DateOnly(2025, 10, 1),
            new DateOnly(2026, 9, 30),
            new ProjectListCountsDto(1, 1, 2),
            new ProjectListSummaryDto(2, 3, 4, 5, 1, []),
            [
                new ProjectListRowDto("CA-A-111-H", "1000001", "2025-1", "K1234", "Larkspur, S.", "ATM", "201", "Clean"),
                new ProjectListRowDto("CA-B-222-CG", "1000002", "2025-2", null, "Okonkwo, Y.", "ANS", "204", "SFN mismatch"),
            ]);

        public Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
        {
            ReceivedCycle = cycle;
            return Task.FromResult(Response);
        }
    }
}
