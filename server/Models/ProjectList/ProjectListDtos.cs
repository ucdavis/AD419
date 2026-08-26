namespace Server.Models.ProjectList;

public sealed record ProjectListResponse(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    ProjectListCountsDto Counts,
    ProjectListSummaryDto Summary,
    IReadOnlyList<ProjectListRowDto> Rows,
    IReadOnlyList<ProjectListRowDto> ExcludedRows);

public sealed record ProjectListCountsDto(
    int Issues,
    int Clean,
    int All,
    int Excluded);

public sealed record ProjectListSummaryDto(
    int ActiveNifa,
    int AllNifa,
    int PgmRecords,
    int AlnCodes,
    int ExcludedNifa,
    int IssuesToResolve,
    IReadOnlyList<SfnDistributionDto> SfnDistribution);

public sealed record SfnDistributionDto(
    string Sfn,
    int Count);

public sealed record ProjectListRowDto(
    string? NifaProject,
    string? Accession,
    string? AwardNumber,
    string? Ae,
    bool Is204,
    string? Notes,
    string? Pi,
    string? PdEmailAddress,
    string? UcpEmployeeId,
    string? UcPathName,
    string? Department,
    string? Sfn,
    string Status);

public sealed record AllProjectCandidateDto(
    int AllProjectId,
    string? AccessionNumber,
    string? ProjectNumber,
    string? AwardNumber,
    string? Title,
    string? Department,
    string? ProjectDirector,
    DateOnly? ProjectStartDate,
    DateOnly? ProjectEndDate);

public sealed record PgmAwardCandidateDto(
    string AwardKey,
    string? SponsorAwardNumber,
    string? AwardName,
    string? ProjectNumbers,
    string? PgmSfnBucket,
    string? PrincipalInvestigatorNames);

public sealed record SfnCandidateDto(
    string Sfn,
    string Description,
    string? Source,
    bool IsRecommended);

public sealed record LinkAllProjectRequest(int? AllProjectId);

public sealed record LinkPgmAwardRequest(string? AwardKey);

public sealed record SetSfnRequest(string? Sfn);

public sealed record ProjectExclusionRequest(string? Notes);

public sealed record ProjectFinalizeResponse(int RowsBuilt);

public sealed record ProjectResolutionEditsResponse(bool HasResolutionEdits);
