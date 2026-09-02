using Server.Models.SegmentClassifications;

namespace Server.Models.OrgR;

public sealed record OrgRDto(string Code, string? Description, int ReferenceCount);

public sealed record UpsertOrgRRequest(string? Description);

public sealed record OrgRFinancialDepartmentDto(
    string FinancialDepartment,
    string? Description,
    IReadOnlyList<HierarchyLevelDto> Hierarchy,
    string? OrgR,
    bool InCycle);

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
