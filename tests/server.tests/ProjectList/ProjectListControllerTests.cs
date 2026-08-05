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

        var result = await controller.LinkAllProject(
            "1000002",
            "FY26",
            new LinkAllProjectRequest(null),
            CancellationToken.None);

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

        var result = await controller.Exclude("1000002", "FY25", CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>();
        service.ReceivedUpdateCycle.Should().Be(new FiscalYearCycle(
            "FY25",
            new DateOnly(2024, 10, 1),
            new DateOnly(2025, 9, 30)));
    }

    [Fact]
    public async Task Candidate_endpoints_return_service_results()
    {
        var service = new StubProjectListService();
        var controller = new ProjectListController(service);

        var allProjects = await controller.AllProjectCandidates("1000002", "FY25", null, CancellationToken.None);
        var pgmAwards = await controller.PgmAwardCandidates("1000002", "FY25", null, CancellationToken.None);
        var sfns = await controller.SfnCandidates("1000002", "FY25", CancellationToken.None);

        allProjects.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<AllProjectCandidateDto>>()
            .Which.Should().ContainSingle();
        pgmAwards.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<PgmAwardCandidateDto>>()
            .Which.Should().ContainSingle();
        sfns.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeAssignableTo<IReadOnlyList<SfnCandidateDto>>()
            .Which.Should().ContainSingle();
        service.ReceivedCandidateCycles.Should().OnlyContain(cycle => cycle == new FiscalYearCycle(
            "FY25",
            new DateOnly(2024, 10, 1),
            new DateOnly(2025, 9, 30)));
    }

    [Fact]
    public async Task Candidate_and_resolution_endpoints_require_fy()
    {
        var controller = new ProjectListController(new StubProjectListService());

        var candidates = await controller.PgmAwardCandidates("1000002", null, null, CancellationToken.None);
        var resolution = await controller.SetSfn(
            "1000002",
            null,
            new SetSfnRequest("204"),
            CancellationToken.None);

        candidates.Result.Should().BeOfType<BadRequestObjectResult>();
        resolution.Should().BeOfType<BadRequestObjectResult>();
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
        public List<FiscalYearCycle> ReceivedCandidateCycles { get; } = [];
        public FiscalYearCycle? ReceivedUpdateCycle { get; private set; }
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
            FiscalYearCycle cycle,
            string accession,
            string? search,
            CancellationToken cancellationToken)
        {
            ReceivedCandidateCycles.Add(cycle);
            return Task.FromResult<IReadOnlyList<AllProjectCandidateDto>>(
            [
                new(1, "1000002", "CA-B-222-CG", "2025-2", "Title", "ANS", "Okonkwo, Y.", null, null),
            ]);
        }

        public Task<IReadOnlyList<PgmAwardCandidateDto>> GetPgmAwardCandidatesAsync(
            FiscalYearCycle cycle,
            string accession,
            string? search,
            CancellationToken cancellationToken)
        {
            ReceivedCandidateCycles.Add(cycle);
            return Task.FromResult<IReadOnlyList<PgmAwardCandidateDto>>(
            [
                new("20252", "2025-2", "Award", "K1234", "204", "Okonkwo, Y."),
            ]);
        }

        public Task<IReadOnlyList<SfnCandidateDto>> GetSfnCandidatesAsync(
            FiscalYearCycle cycle,
            string accession,
            CancellationToken cancellationToken)
        {
            ReceivedCandidateCycles.Add(cycle);
            return Task.FromResult<IReadOnlyList<SfnCandidateDto>>(
            [
                new("204", "Contracts, Grants, Research Coop Agreements", "PGM master data", true),
            ]);
        }

        public Task<ProjectListUpdateResult> ExcludeAsync(
            FiscalYearCycle cycle,
            string accession,
            CancellationToken cancellationToken)
        {
            ReceivedUpdateCycle = cycle;
            return Task.FromResult(NextUpdateResult);
        }

        public Task<ProjectListUpdateResult> LinkAllProjectAsync(
            FiscalYearCycle cycle,
            string accession,
            int allProjectId,
            CancellationToken cancellationToken)
        {
            ReceivedUpdateCycle = cycle;
            return Task.FromResult(NextUpdateResult);
        }

        public Task<ProjectListUpdateResult> LinkPgmAwardAsync(
            FiscalYearCycle cycle,
            string accession,
            string awardKey,
            CancellationToken cancellationToken)
        {
            ReceivedUpdateCycle = cycle;
            return Task.FromResult(NextUpdateResult);
        }

        public Task<ProjectListUpdateResult> SetSfnAsync(
            FiscalYearCycle cycle,
            string accession,
            string sfn,
            CancellationToken cancellationToken)
        {
            ReceivedUpdateCycle = cycle;
            return Task.FromResult(NextUpdateResult);
        }

        public Task<int> BuildProjectsAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            Task.FromResult(12);
    }
}
