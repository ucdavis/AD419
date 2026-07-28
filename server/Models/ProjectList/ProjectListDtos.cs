namespace Server.Models.ProjectList;

public sealed record ProjectListResponse(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    ProjectListCountsDto Counts,
    ProjectListSummaryDto Summary,
    IReadOnlyList<ProjectListRowDto> Rows);

public sealed record ProjectListCountsDto(
    int Issues,
    int Clean,
    int All);

public sealed record ProjectListSummaryDto(
    int ActiveNifa,
    int AllNifa,
    int PgmRecords,
    int AlnCodes,
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
    string? Pi,
    string? UcpEmployeeId,
    string? UcPathName,
    string? Department,
    string? Sfn,
    string Status);
