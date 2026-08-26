using Server.Models.ProjectList;
using Server.Models;

namespace Server.ProjectList;

public interface IProjectListService
{
    Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);

    Task<bool> HasResolutionEditsAsync(CancellationToken cancellationToken);

    Task<IReadOnlyList<AllProjectCandidateDto>> GetAllProjectCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        string? search,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<PgmAwardCandidateDto>> GetPgmAwardCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        string? search,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<SfnCandidateDto>> GetSfnCandidatesAsync(
        FiscalYearCycle cycle,
        string accession,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> ExcludeAsync(
        FiscalYearCycle cycle,
        string accession,
        string? notes,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> IncludeAsync(
        FiscalYearCycle cycle,
        string accession,
        string? notes,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> LinkAllProjectAsync(
        FiscalYearCycle cycle,
        string accession,
        int allProjectId,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> LinkPgmAwardAsync(
        FiscalYearCycle cycle,
        string accession,
        string awardKey,
        CancellationToken cancellationToken);

    Task<ProjectListUpdateResult> SetSfnAsync(
        FiscalYearCycle cycle,
        string accession,
        string sfn,
        CancellationToken cancellationToken);

    Task<int> BuildProjectsAsync(FiscalYearCycle cycle, CancellationToken cancellationToken);
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
