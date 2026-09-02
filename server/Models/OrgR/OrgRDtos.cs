using Server.Models.SegmentClassifications;

namespace Server.Models.OrgR;

/// <summary>
/// FinancialDepartmentCount and NifaProjectCount are what the user sees;
/// ReferenceCount is every mapping row pointing at the OrgR (departments,
/// NIFA departments, manual project additions) and gates deletion.
/// </summary>
public sealed record OrgRDto(string Code, int FinancialDepartmentCount, int NifaProjectCount, int ReferenceCount);

public sealed record OrgRFinancialDepartmentDto(
    string FinancialDepartment,
    string? Description,
    IReadOnlyList<HierarchyLevelDto> Hierarchy,
    string? OrgR);

public sealed record SetOrgRRequest(string? OrgR);

public sealed record OrgRNifaDepartmentDto(string NifaDepartment, string? OrgR, int ProjectCount);

public sealed record ProjectOrgRDto(
    string AccessionNumber,
    string NifaProjectNumber,
    string? Title,
    string? ProjectDirector,
    string OrgR,
    string Source);

public sealed record AddProjectOrgRRequest(string AccessionNumber, string OrgR);
