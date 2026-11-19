namespace Server.Models.JobCodeClassifications;

/// <summary>
/// One UCPath job code on payroll that is inside the cycle window and included in the report.
/// FteSfn is the job SFN (FTE line) the title's staff type reports on, null while unassigned.
/// Blocking is true when the code is unassigned and assigning it can change the build: one of
/// its expense summary rows has dollars and either reports FTE or is on State Appropriations
/// (13U02). EmployeeCount, Amount and Fte are totals over all of the code's included rows, so
/// Amount and Fte can be zero when summary rows offset each other.
/// </summary>
public sealed record JobCodeClassificationDto(
    string JobCode,
    string? TitleName,
    string? StaffTypeCode,
    string? FteSfn,
    bool Blocking,
    int EmployeeCount,
    decimal Amount,
    decimal Fte);

/// <summary>A staff type a job code can be assigned to. Only staff types with a line are offered.</summary>
public sealed record StaffTypeOptionDto(string StaffTypeCode, string FteSfn, string? Description);

public sealed record JobCodeClassificationsResponse(
    string FiscalYear,
    DateOnly CycleStart,
    DateOnly CycleEnd,
    IReadOnlyList<JobCodeClassificationDto> Rows,
    IReadOnlyList<StaffTypeOptionDto> StaffTypes);

public sealed record UpdateJobCodeClassificationRequest(string? JobCode, string? StaffTypeCode);
