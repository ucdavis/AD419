using Server.Models.ProjectList;
using Server.Models;

namespace Server.ProjectList;

public interface IProjectListService
{
    Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    Task<bool> HasResolutionEditsAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<AllProjectCandidateDto>> GetAllProjectCandidatesAsync(
        string accession,
        string? search,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<PgmAwardCandidateDto>> GetPgmAwardCandidatesAsync(
        string accession,
        string? search,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<SfnCandidateDto>> GetSfnCandidatesAsync(
        string accession,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> ExcludeAsync(string accession, CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> LinkAllProjectAsync(
        string accession,
        int allProjectId,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> LinkPgmAwardAsync(
        string accession,
        string awardKey,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> SetSfnAsync(
        string accession,
        string sfn,
        CancellationToken cancellationToken);

    Task<int> BuildProjectsAsync(CancellationToken cancellationToken);
}

public enum ProjectListUpdateStatus
{
    Updated,
    NotFound,
    Conflict,
    InvalidRequest,
}

public sealed record ProjectListUpdateResult(
    ProjectListUpdateStatus Status,
    string? Message = null)
{
    public static ProjectListUpdateResult Updated { get; } = new(ProjectListUpdateStatus.Updated);
}
