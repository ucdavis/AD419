using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Helpers;
using Server.Models.OrgR;
using Server.Models.SegmentClassifications;
using Server.OrgRReview;
using Server.Workflow;

namespace Server.Controllers;

public partial class OrgRController(DataDbContext db, IOrgRReviewSeeder seeder, IWorkflowService workflowService) : ApiControllerBase
{
    [GeneratedRegex("^[A-Z0-9]{1,10}$")]
    private static partial Regex OrgRCodePattern();

    // PI appointments never move 204 projects: those follow their AE project
    // and stay on the default OrgR only.
    private const string Sfn204 = "204";

    // GET api/orgr/orgrs
    [HttpGet("orgrs")]
    public async Task<ActionResult<IReadOnlyList<OrgRDto>>> GetOrgRs(CancellationToken cancellationToken)
    {
        var orgRs = await db.OrgRs.OrderBy(o => o.Code).ToListAsync(cancellationToken);
        var departmentRefs = await db.OrgRFinancialDepartments
            .Where(m => m.OrgR != null)
            .GroupBy(m => m.OrgR!)
            .Select(g => new { OrgR = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.OrgR, g => g.Count, cancellationToken);
        var nifaRefs = await db.OrgRNifaDepartments
            .Where(m => m.OrgR != null)
            .GroupBy(m => m.OrgR!)
            .Select(g => new { OrgR = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.OrgR, g => g.Count, cancellationToken);
        var appointments = await db.OrgRPiAppointments.ToListAsync(cancellationToken);
        var appointmentRefs = appointments
            .GroupBy(a => a.OrgR)
            .ToDictionary(g => g.Key, g => g.Count());

        // NIFA projects per OrgR: distinct accessions that land on the OrgR
        // through the NIFA department mapping or a PI appointment, the same
        // union [data].[v_ProjXOrgR] exposes.
        var nifaMap = await db.OrgRNifaDepartments
            .Where(m => m.OrgR != null)
            .ToDictionaryAsync(m => m.NifaDepartment, m => m.OrgR!, cancellationToken);
        var projectPairs = await db.Projects
            .Select(p => new { p.AccessionNumber, p.NifaProjectNumber, p.UcpEmployeeId, p.Sfn })
            .Distinct()
            .ToListAsync(cancellationToken);
        var projectsByOrgR = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in projectPairs)
        {
            if (NifaDepartmentOf(pair.NifaProjectNumber) is { } dept && nifaMap.TryGetValue(dept, out var orgR))
            {
                ProjectsFor(orgR).Add(pair.AccessionNumber);
            }
        }

        foreach (var appointment in appointments)
        {
            var placed = projectPairs
                .Where(p => p.UcpEmployeeId == appointment.UcpEmployeeId && p.Sfn != Sfn204);
            foreach (var pair in placed)
            {
                ProjectsFor(appointment.OrgR).Add(pair.AccessionNumber);
            }
        }

        var dtos = orgRs
            .Select(o => new OrgRDto(
                o.Code,
                departmentRefs.GetValueOrDefault(o.Code),
                projectsByOrgR.TryGetValue(o.Code, out var projects) ? projects.Count : 0,
                departmentRefs.GetValueOrDefault(o.Code)
                    + nifaRefs.GetValueOrDefault(o.Code)
                    + appointmentRefs.GetValueOrDefault(o.Code)))
            .ToList();

        return Ok(dtos);

        HashSet<string> ProjectsFor(string orgR)
        {
            if (!projectsByOrgR.TryGetValue(orgR, out var set))
            {
                set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                projectsByOrgR[orgR] = set;
            }

            return set;
        }
    }

    // PUT api/orgr/orgrs/{code}
    // Idempotent create: an OrgR is only its code, so a second PUT is a no-op.
    [HttpPut("orgrs/{code}")]
    public async Task<IActionResult> CreateOrgR(string code, CancellationToken cancellationToken)
    {
        var normalized = NormalizeCode(code);
        if (normalized is null)
        {
            return BadRequest("OrgR codes are 1 to 10 letters or digits.");
        }

        if (!await OrgRExistsAsync(normalized, cancellationToken))
        {
            db.OrgRs.Add(new OrgR { Code = normalized });
            await db.SaveChangesAsync(cancellationToken);
        }

        return NoContent();
    }

    // DELETE api/orgr/orgrs/{code}
    [HttpDelete("orgrs/{code}")]
    public async Task<IActionResult> DeleteOrgR(string code, CancellationToken cancellationToken)
    {
        var normalized = NormalizeCode(code);
        if (normalized is null)
        {
            return BadRequest("OrgR codes are 1 to 10 letters or digits.");
        }

        var existing = await db.OrgRs.FindAsync([normalized], cancellationToken);
        if (existing is null)
        {
            return NotFound();
        }

        if (normalized == "ADNO")
        {
            return Conflict("ADNO is required by the title code 1010 rule and cannot be deleted.");
        }

        var references =
            await db.OrgRFinancialDepartments.CountAsync(m => m.OrgR == normalized, cancellationToken)
            + await db.OrgRNifaDepartments.CountAsync(m => m.OrgR == normalized, cancellationToken)
            + await db.OrgRPiAppointments.CountAsync(a => a.OrgR == normalized, cancellationToken);

        if (references > 0)
        {
            var noun = references == 1 ? "mapping" : "mappings";
            return Conflict($"{normalized} is used by {references} {noun}. Reassign them before deleting it.");
        }

        db.OrgRs.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // GET api/orgr/financial-departments
    // Only departments classified as included in this cycle's report are
    // returned, matching what SeedOrgRReviewRows seeds. Mapping rows for
    // departments excluded this cycle (or carried forward from an earlier one)
    // stay in the table but are hidden. The completion gate in WorkflowService
    // applies the same filter.
    [HttpGet("financial-departments")]
    public async Task<ActionResult<IReadOnlyList<OrgRFinancialDepartmentDto>>> GetFinancialDepartments(
        CancellationToken cancellationToken)
    {
        await seeder.SeedReviewRowsAsync(cancellationToken);

        var inCycle = await db.SegmentClassifications
            .Where(s => s.SegmentType == SegmentType.FinancialDepartment && s.IncludeInReport == true)
            .Select(s => s.Code)
            .ToHashSetAsync(cancellationToken);
        var mappings = await db.OrgRFinancialDepartments
            .OrderBy(m => m.FinancialDepartment)
            .ToListAsync(cancellationToken);

        // Name and hierarchy come from the AE chart segment reference data;
        // parent codes are segment rows too, so their names resolve from the
        // same dictionary.
        var segments = await db.ChartSegments
            .Where(s => s.SegmentName == FinancialDepartmentSegment)
            .ToDictionaryAsync(s => s.Code, cancellationToken);

        var dtos = mappings
            .Where(m => inCycle.Contains(m.FinancialDepartment))
            .Select(m =>
            {
                var segment = segments.GetValueOrDefault(m.FinancialDepartment);
                return new OrgRFinancialDepartmentDto(
                    m.FinancialDepartment,
                    segment?.Description,
                    HierarchyFor(segment, segments),
                    m.OrgR);
            })
            .ToList();

        return Ok(dtos);
    }

    private const string FinancialDepartmentSegment = "FinancialDepartment";

    // Levels are lettered A (root) downward to match the hierarchy display
    // used by Data Classification.
    private static IReadOnlyList<HierarchyLevelDto> HierarchyFor(
        ChartSegment? segment,
        IReadOnlyDictionary<string, ChartSegment> segments)
    {
        if (segment is null)
        {
            return [];
        }

        return segment.ParentCodes()
            .Select((code, index) => new HierarchyLevelDto(
                ((char)('A' + index)).ToString(),
                code,
                segments.GetValueOrDefault(code)?.Description))
            .ToList();
    }

    // PATCH api/orgr/financial-departments/{code}
    [HttpPatch("financial-departments/{code}")]
    public async Task<IActionResult> SetFinancialDepartmentOrgR(
        string code,
        [FromBody] SetOrgRRequest request,
        CancellationToken cancellationToken)
    {
        ApiOperationContext.Set(HttpContext,
            ("OrgR", request.OrgR));

        // Mapping keys are data-derived codes the client echoes back from the GET payload, so no normalization is applied.
        var mapping = await db.OrgRFinancialDepartments.FindAsync([code], cancellationToken);
        if (mapping is null)
        {
            return NotFound();
        }

        var (orgR, error) = await ResolveOrgRAsync(request.OrgR, cancellationToken);
        if (error is not null)
        {
            return BadRequest(error);
        }

        if (mapping.OrgR == orgR)
        {
            return NoContent();
        }

        // Reset first so a failed reset leaves the mapping retryable. If saving then fails,
        // keeping the review reopened is safer than leaving changed mappings marked complete.
        await workflowService.ResetFromStageAsync(WorkflowStageIds.OrgRReview, User, cancellationToken);
        mapping.OrgR = orgR;
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // GET api/orgr/nifa-departments
    [HttpGet("nifa-departments")]
    public async Task<ActionResult<IReadOnlyList<OrgRNifaDepartmentDto>>> GetNifaDepartments(
        CancellationToken cancellationToken)
    {
        await seeder.SeedReviewRowsAsync(cancellationToken);

        var mappings = await db.OrgRNifaDepartments
            .OrderBy(m => m.NifaDepartment)
            .ToListAsync(cancellationToken);
        // Projects is at NIFA x AE grain, so multiple rows can share an
        // AccessionNumber; dedupe by accession before counting so a project
        // with several AE rows is not counted more than once.
        var projectNumbers = (await db.Projects
                .Select(p => new { p.AccessionNumber, p.NifaProjectNumber })
                .ToListAsync(cancellationToken))
            .GroupBy(p => p.AccessionNumber)
            .Select(g => g.First().NifaProjectNumber)
            .ToList();
        var counts = projectNumbers
            .Select(NifaDepartmentOf)
            .Where(d => d is not null)
            .GroupBy(d => d!)
            .ToDictionary(g => g.Key, g => g.Count());

        var dtos = mappings
            .Select(m => new OrgRNifaDepartmentDto(m.NifaDepartment, m.OrgR, counts.GetValueOrDefault(m.NifaDepartment)))
            .ToList();

        return Ok(dtos);
    }

    // PATCH api/orgr/nifa-departments/{code}
    [HttpPatch("nifa-departments/{code}")]
    public async Task<IActionResult> SetNifaDepartmentOrgR(
        string code,
        [FromBody] SetOrgRRequest request,
        CancellationToken cancellationToken)
    {
        ApiOperationContext.Set(HttpContext,
            ("OrgR", request.OrgR));

        // Mapping keys are data-derived codes the client echoes back from the GET payload, so no normalization is applied.
        var mapping = await db.OrgRNifaDepartments.FindAsync([code], cancellationToken);
        if (mapping is null)
        {
            return NotFound();
        }

        var (orgR, error) = await ResolveOrgRAsync(request.OrgR, cancellationToken);
        if (error is not null)
        {
            return BadRequest(error);
        }

        if (mapping.OrgR == orgR)
        {
            return NoContent();
        }

        // Reset first so a failed reset leaves the mapping retryable. If saving then fails,
        // keeping the review reopened is safer than leaving changed mappings marked complete.
        await workflowService.ResetFromStageAsync(WorkflowStageIds.OrgRReview, User, cancellationToken);
        mapping.OrgR = orgR;
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // GET api/orgr/pis
    // The PIs an appointment can be added for: everyone directing at least
    // one non-204 project this cycle.
    [HttpGet("pis")]
    public async Task<ActionResult<IReadOnlyList<PiDto>>> GetPis(CancellationToken cancellationToken)
    {
        var projects = await LoadPiProjectsAsync(cancellationToken);
        var dtos = projects
            .Where(p => p.Sfn != Sfn204)
            .GroupBy(p => p.UcpEmployeeId)
            .Select(g => new PiDto(g.Key, PiNameOf(g, g.Key), g.Count()))
            .OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase)
            .ThenBy(d => d.UcpEmployeeId)
            .ToList();

        return Ok(dtos);
    }

    // GET api/orgr/pi-appointments
    [HttpGet("pi-appointments")]
    public async Task<ActionResult<IReadOnlyList<PiAppointmentDto>>> GetPiAppointments(CancellationToken cancellationToken)
    {
        var appointments = await db.OrgRPiAppointments.ToListAsync(cancellationToken);
        var nifaMap = await db.OrgRNifaDepartments
            .Where(m => m.OrgR != null)
            .ToDictionaryAsync(m => m.NifaDepartment, m => m.OrgR!, cancellationToken);
        var projectsByPi = (await LoadPiProjectsAsync(cancellationToken)).ToLookup(p => p.UcpEmployeeId);

        var dtos = appointments
            .Select(a =>
            {
                var projects = projectsByPi[a.UcpEmployeeId].ToList();
                var placed = projects.Where(p => p.Sfn != Sfn204).ToList();
                var homeOrgRs = new List<string>();
                foreach (var project in placed)
                {
                    var department = NifaDepartmentOf(project.NifaProjectNumber);
                    if (department != null
                        && nifaMap.TryGetValue(department, out var home)
                        && !homeOrgRs.Contains(home))
                    {
                        homeOrgRs.Add(home);
                    }
                }

                homeOrgRs.Sort(StringComparer.Ordinal);
                // The current project list names the PI; the stored name only
                // covers a PI with no projects this cycle.
                var name = PiNameOf(projects, a.PiName ?? a.UcpEmployeeId);
                return new PiAppointmentDto(
                    a.UcpEmployeeId, name, a.OrgR, homeOrgRs, placed.Count, projects.Count - placed.Count);
            })
            .OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase)
            .ThenBy(d => d.UcpEmployeeId)
            .ThenBy(d => d.OrgR)
            .ToList();

        return Ok(dtos);
    }

    // POST api/orgr/pi-appointments
    [HttpPost("pi-appointments")]
    public async Task<IActionResult> AddPiAppointment(
        [FromBody] AddPiAppointmentRequest request,
        CancellationToken cancellationToken)
    {
        ApiOperationContext.Set(HttpContext,
            ("UcpEmployeeId", request.UcpEmployeeId), ("OrgR", request.OrgR));

        var employeeId = request.UcpEmployeeId?.Trim();
        var projects = string.IsNullOrEmpty(employeeId)
            ? []
            : (await LoadPiProjectsAsync(cancellationToken)).Where(p => p.UcpEmployeeId == employeeId).ToList();
        if (string.IsNullOrEmpty(employeeId) || projects.Count == 0)
        {
            return BadRequest($"No PI on the project list has employee ID '{request.UcpEmployeeId}'.");
        }

        var (orgR, error) = await ResolveOrgRAsync(request.OrgR, cancellationToken);
        if (orgR is null)
        {
            return BadRequest(error ?? "An OrgR is required.");
        }

        var name = PiNameOf(projects, employeeId);
        if (await db.OrgRPiAppointments.AnyAsync(a => a.UcpEmployeeId == employeeId && a.OrgR == orgR, cancellationToken))
        {
            return Conflict($"{name} already has an appointment in {orgR}.");
        }

        db.OrgRPiAppointments.Add(new OrgRPiAppointment { UcpEmployeeId = employeeId, OrgR = orgR, PiName = name });
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // DELETE api/orgr/pi-appointments/{ucpEmployeeId}/{orgR}
    [HttpDelete("pi-appointments/{ucpEmployeeId}/{orgR}")]
    public async Task<IActionResult> RemovePiAppointment(string ucpEmployeeId, string orgR, CancellationToken cancellationToken)
    {
        var normalized = NormalizeCode(orgR);
        var appointment = normalized is null
            ? null
            : await db.OrgRPiAppointments.FindAsync([ucpEmployeeId, normalized], cancellationToken);
        if (appointment is null)
        {
            return NotFound();
        }

        db.OrgRPiAppointments.Remove(appointment);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    /// <summary>Characters 6 to 8 of a NIFA project number, e.g. CA-D-ARE-2868-H gives ARE.</summary>
    internal static string? NifaDepartmentOf(string? nifaProjectNumber) =>
        nifaProjectNumber is { Length: >= 8 } ? nifaProjectNumber.Substring(5, 3) : null;

    private sealed record PiProject(
        string UcpEmployeeId, string AccessionNumber, string NifaProjectNumber, string? ProjectDirector, string Sfn);

    // One row per project that has a PI. Projects is at NIFA x AE grain, so
    // rows sharing an accession are collapsed to the first.
    private async Task<List<PiProject>> LoadPiProjectsAsync(CancellationToken cancellationToken)
    {
        var rows = await db.Projects
            .Where(p => p.UcpEmployeeId != null && p.UcpEmployeeId != "")
            .OrderBy(p => p.AccessionNumber)
            .Select(p => new PiProject(p.UcpEmployeeId!, p.AccessionNumber, p.NifaProjectNumber, p.ProjectDirector, p.Sfn))
            .ToListAsync(cancellationToken);

        return rows.GroupBy(p => p.AccessionNumber).Select(g => g.First()).ToList();
    }

    // The same person can be spelled differently across projects, so pick one
    // spelling deterministically.
    private static string PiNameOf(IEnumerable<PiProject> projects, string fallback)
    {
        var name = projects
            .Select(p => p.ProjectDirector?.Trim())
            .Where(n => !string.IsNullOrEmpty(n))
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault();

        return name ?? fallback;
    }

    // Null request clears the mapping. A non-null value must be an existing OrgR.
    private async Task<(string? OrgR, string? Error)> ResolveOrgRAsync(string? requested, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(requested))
        {
            return (null, null);
        }

        var normalized = NormalizeCode(requested);
        if (normalized is null || !await OrgRExistsAsync(normalized, cancellationToken))
        {
            return (null, $"Unknown OrgR '{requested}'.");
        }

        return (normalized, null);
    }

    private static string? NormalizeCode(string? code)
    {
        var trimmed = code?.Trim().ToUpperInvariant();
        return trimmed is not null && OrgRCodePattern().IsMatch(trimmed) ? trimmed : null;
    }

    private async Task<bool> OrgRExistsAsync(string code, CancellationToken cancellationToken) =>
        await db.OrgRs.AnyAsync(o => o.Code == code, cancellationToken);
}
