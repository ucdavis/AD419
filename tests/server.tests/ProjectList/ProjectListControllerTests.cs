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

    [Fact]
    public async Task Link_all_project_requires_id()
    {
        var controller = new ProjectListController(new StubProjectListService());

        var result = await controller.LinkAllProject("1000002", new LinkAllProjectRequest(null), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>();
    }

    [Fact]
    public async Task Exclude_maps_conflicts_from_service()
    {
        var service = new StubProjectListService
        {
            NextUpdateResult = new ProjectListUpdateResult(ProjectListUpdateStatus.Conflict, "Wrong status."),
        };
        var controller = new ProjectListController(service);

        var result = await controller.Exclude("1000002", CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>();
    }

    [Fact]
    public async Task Candidate_endpoints_return_service_results()
    {
        var controller = new ProjectListController(new StubProjectListService());

        var allProjects = await controller.AllProjectCandidates("1000002", null, CancellationToken.None);
        var pgmAwards = await controller.PgmAwardCandidates("1000002", null, CancellationToken.None);
        var sfns = await controller.SfnCandidates("1000002", CancellationToken.None);

        allProjects.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<AllProjectCandidateDto>>()
            .Which.Should().ContainSingle();
        pgmAwards.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<PgmAwardCandidateDto>>()
            .Which.Should().ContainSingle();
        sfns.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<SfnCandidateDto>>()
            .Which.Should().ContainSingle();
    }

    [Fact]
    public async Task Resolution_edits_returns_service_flag()
    {
        var controller = new ProjectListController(new StubProjectListService { HasResolutionEdits = true });

        var result = await controller.ResolutionEdits(CancellationToken.None);

        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(new ProjectResolutionEditsResponse(true));
    }

    private sealed class StubProjectListService : IProjectListService
    {
        public FiscalYearCycle? ReceivedCycle { get; private set; }
        public bool HasResolutionEdits { get; init; }
        public ProjectListUpdateResult NextUpdateResult { get; init; } = ProjectListUpdateResult.Updated;

        public ProjectListResponse Response { get; } = new(
            "FY26",
            new DateOnly(2025, 10, 1),
            new DateOnly(2026, 9, 30),
            new ProjectListCountsDto(1, 1, 2),
            new ProjectListSummaryDto(2, 3, 4, 5, 1, []),
            [
                new ProjectListRowDto(
                    "CA-A-111-H",
                    "1000001",
                    "2025-1",
                    "K1234",
                    false,
                    null,
                    "Larkspur, S.",
                    "larkspur@example.edu",
                    "10000001",
                    "Larkspur, Sasha",
                    "ATM",
                    "201",
                    "Clean"),
                new ProjectListRowDto(
                    "CA-B-222-CG",
                    "1000002",
                    "2025-2",
                    null,
                    true,
                    null,
                    "Okonkwo, Y.",
                    "okonkwo@example.edu",
                    "10000002",
                    "Okonkwo, Yara",
                    "ANS",
                    "204",
                    "SFN mismatch"),
            ]);

        public Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
        {
            ReceivedCycle = cycle;
            return Task.FromResult(Response);
        }

        public Task<bool> HasResolutionEditsAsync(CancellationToken cancellationToken) =>
            Task.FromResult(HasResolutionEdits);

        public Task<IReadOnlyList<AllProjectCandidateDto>> GetAllProjectCandidatesAsync(
            string accession,
            string? search,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<AllProjectCandidateDto>>(
            [
                new(1, "1000002", "CA-B-222-CG", "2025-2", "Title", "ANS", "Okonkwo, Y.", null, null),
            ]);

        public Task<IReadOnlyList<PgmAwardCandidateDto>> GetPgmAwardCandidatesAsync(
            string accession,
            string? search,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<PgmAwardCandidateDto>>(
            [
                new("20252", "2025-2", "Award", "K1234", "204", "Okonkwo, Y."),
            ]);

        public Task<IReadOnlyList<SfnCandidateDto>> GetSfnCandidatesAsync(
            string accession,
            CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<SfnCandidateDto>>([new("204", "PGM master data")]);

        public Task<ProjectListUpdateResult> ExcludeAsync(string accession, CancellationToken cancellationToken) =>
            Task.FromResult(NextUpdateResult);

        public Task<ProjectListUpdateResult> LinkAllProjectAsync(
            string accession,
            int allProjectId,
            CancellationToken cancellationToken) =>
            Task.FromResult(NextUpdateResult);

        public Task<ProjectListUpdateResult> LinkPgmAwardAsync(
            string accession,
            string awardKey,
            CancellationToken cancellationToken) =>
            Task.FromResult(NextUpdateResult);

        public Task<ProjectListUpdateResult> SetSfnAsync(
            string accession,
            string sfn,
            CancellationToken cancellationToken) =>
            Task.FromResult(NextUpdateResult);

        public Task<int> BuildProjectsAsync(CancellationToken cancellationToken) =>
            Task.FromResult(12);
    }
}
