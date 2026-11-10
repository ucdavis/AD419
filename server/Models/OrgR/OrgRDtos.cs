using Server.Models.SegmentClassifications;

namespace Server.Models.OrgR;

/// <summary>
/// FinancialDepartmentCount and NifaProjectCount are what the user sees;
/// ReferenceCount is every mapping row pointing at the OrgR (departments,
/// NIFA departments, PI appointments) and gates deletion.
/// </summary>
public sealed record OrgRDto(string Code, int FinancialDepartmentCount, int NifaProjectCount, int ReferenceCount);

public sealed record OrgRFinancialDepartmentDto(
    string FinancialDepartment,
    string? Description,
    IReadOnlyList<HierarchyLevelDto> Hierarchy,
    string? OrgR);

public sealed record SetOrgRRequest(string? OrgR);

public sealed record OrgRNifaDepartmentDto(string NifaDepartment, string? OrgR, int ProjectCount);

/// <summary>A PI who can be given an appointment. ProjectCount leaves out 204 projects, which appointments never move.</summary>
public sealed record PiDto(string UcpEmployeeId, string Name, int ProjectCount);

/// <summary>
/// HomeOrgRs are the default OrgRs of the PI's non-204 projects. ProjectCount
/// is how many projects the appointment places on OrgR; Skipped204Count is how
/// many 204 projects it leaves on their default OrgR.
/// </summary>
public sealed record PiAppointmentDto(
    string UcpEmployeeId,
    string Name,
    string OrgR,
    IReadOnlyList<string> HomeOrgRs,
    int ProjectCount,
    int Skipped204Count);

public sealed record AddPiAppointmentRequest(string UcpEmployeeId, string OrgR);
