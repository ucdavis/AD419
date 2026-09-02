using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.OrgR;
using Server.Models.SegmentClassifications;
using Server.OrgRReview;

namespace Server.Controllers;

public partial class OrgRController(DataDbContext db, IOrgRReviewSeeder seeder) : ApiControllerBase
{
    [GeneratedRegex("^[A-Z0-9]{1,10}$")]
    private static partial Regex OrgRCodePattern();

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
        var additionRefs = await db.OrgRProjectAdditions
            .GroupBy(a => a.OrgR)
            .Select(g => new { OrgR = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.OrgR, g => g.Count, cancellationToken);

        var dtos = orgRs
            .Select(o => new OrgRDto(
                o.Code,
                o.Description,
                departmentRefs.GetValueOrDefault(o.Code)
                    + nifaRefs.GetValueOrDefault(o.Code)
                    + additionRefs.GetValueOrDefault(o.Code)))
            .ToList();

        return Ok(dtos);
    }

    // PUT api/orgr/orgrs/{code}
    [HttpPut("orgrs/{code}")]
    public async Task<IActionResult> UpsertOrgR(
        string code,
        [FromBody] UpsertOrgRRequest request,
        CancellationToken cancellationToken)
    {
        var normalized = NormalizeCode(code);
        if (normalized is null)
        {
            return BadRequest("OrgR codes are 1 to 10 letters or digits.");
        }

        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        if (description is { Length: > 200 })
        {
            return BadRequest("Description must be 200 characters or fewer.");
        }

        var existing = await db.OrgRs.FindAsync([normalized], cancellationToken);
        if (existing is null)
        {
            db.OrgRs.Add(new OrgR { Code = normalized, Description = description });
        }
        else
        {
            existing.Description = description;
        }

        await db.SaveChangesAsync(cancellationToken);
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
            + await db.OrgRProjectAdditions.CountAsync(a => a.OrgR == normalized, cancellationToken);

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
    [HttpGet("financial-departments")]
    public async Task<ActionResult<IReadOnlyList<OrgRFinancialDepartmentDto>>> GetFinancialDepartments(
        CancellationToken cancellationToken)
    {
        await seeder.SeedReviewRowsAsync(cancellationToken);

        var mappings = await db.OrgRFinancialDepartments
            .OrderBy(m => m.FinancialDepartment)
            .ToListAsync(cancellationToken);
        var hierarchy = await db.DepartmentHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);

        // SeedSegmentClassifications inserts every department present in the
        // imported transactions, so presence there means "in this cycle".
        var inCycle = await db.SegmentClassifications
            .Where(s => s.SegmentType == SegmentType.FinancialDepartment)
            .Select(s => s.Code)
            .ToHashSetAsync(cancellationToken);

        var dtos = mappings
            .Select(m =>
            {
                var source = hierarchy.GetValueOrDefault(m.FinancialDepartment);
                IReadOnlyList<HierarchyLevelDto> levels = source is null
                    ? []
                    : source.Levels().Select(l => new HierarchyLevelDto(l.Level, l.Code, l.Name)).ToList();
                return new OrgRFinancialDepartmentDto(
                    m.FinancialDepartment,
                    source?.Description,
                    levels,
                    m.OrgR,
                    inCycle.Contains(m.FinancialDepartment));
            })
            .ToList();

        return Ok(dtos);
    }

    // PATCH api/orgr/financial-departments/{code}
    [HttpPatch("financial-departments/{code}")]
    public async Task<IActionResult> SetFinancialDepartmentOrgR(
        string code,
        [FromBody] SetOrgRRequest request,
        CancellationToken cancellationToken)
    {
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

        mapping.OrgR = orgR;
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // GET api/orgr/projects
    // Mirrors [data].[v_ProjXOrgR] in LINQ so the grid can be served and
    // tested through DataDbContext. Keep the two in step.
    [HttpGet("projects")]
    public async Task<ActionResult<IReadOnlyList<ProjectOrgRDto>>> GetProjects(CancellationToken cancellationToken)
    {
        var projects = await db.Projects
            .OrderBy(p => p.AccessionNumber)
            .ToListAsync(cancellationToken);
        var nifaMap = await db.OrgRNifaDepartments
            .Where(m => m.OrgR != null)
            .ToDictionaryAsync(m => m.NifaDepartment, m => m.OrgR!, cancellationToken);
        var additions = await db.OrgRProjectAdditions.ToListAsync(cancellationToken);
        // Projects is at NIFA x AE grain, so several rows can share the same
        // (AccessionNumber, NifaProjectNumber) pair; dedupe to one row per
        // project before building the Default rows so the grid shows each
        // project once per OrgR.
        var projectsByAccession = projects
            .GroupBy(p => p.AccessionNumber)
            .ToDictionary(g => g.Key, g => g.First());

        var defaults = projectsByAccession.Values
            .Select(p => (Project: p, OrgR: NifaDepartmentOf(p.NifaProjectNumber) is { } dept ? nifaMap.GetValueOrDefault(dept) : null))
            .Where(x => x.OrgR is not null)
            .Select(x => ToDto(x.Project, x.OrgR!, "Default"));

        var manual = additions
            .Where(a => projectsByAccession.ContainsKey(a.AccessionNumber))
            .Select(a => ToDto(projectsByAccession[a.AccessionNumber], a.OrgR, "Manual"));

        return Ok(defaults.Concat(manual)
            .OrderBy(d => d.AccessionNumber)
            .ThenBy(d => d.Source)
            .ThenBy(d => d.OrgR)
            .ToList());

        static ProjectOrgRDto ToDto(Project p, string orgR, string source) =>
            new(p.AccessionNumber, p.NifaProjectNumber, p.Title, p.ProjectDirector, orgR, source);
    }

    // POST api/orgr/projects
    [HttpPost("projects")]
    public async Task<IActionResult> AddProject(
        [FromBody] AddProjectOrgRRequest request,
        CancellationToken cancellationToken)
    {
        var accession = request.AccessionNumber?.Trim();
        if (string.IsNullOrEmpty(accession)
            || !await db.Projects.AnyAsync(p => p.AccessionNumber == accession, cancellationToken))
        {
            return BadRequest($"Unknown accession number '{request.AccessionNumber}'.");
        }

        var (orgR, error) = await ResolveOrgRAsync(request.OrgR, cancellationToken);
        if (orgR is null)
        {
            return BadRequest(error ?? "An OrgR is required.");
        }

        if (await db.OrgRProjectAdditions.AnyAsync(a => a.AccessionNumber == accession && a.OrgR == orgR, cancellationToken))
        {
            return Conflict($"{accession} is already added to {orgR}.");
        }

        db.OrgRProjectAdditions.Add(new OrgRProjectAddition { AccessionNumber = accession, OrgR = orgR });
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    // DELETE api/orgr/projects/{accessionNumber}/{orgR}
    [HttpDelete("projects/{accessionNumber}/{orgR}")]
    public async Task<IActionResult> RemoveProject(string accessionNumber, string orgR, CancellationToken cancellationToken)
    {
        var normalized = NormalizeCode(orgR);
        var addition = normalized is null
            ? null
            : await db.OrgRProjectAdditions.FindAsync([accessionNumber, normalized], cancellationToken);
        if (addition is null)
        {
            return NotFound();
        }

        db.OrgRProjectAdditions.Remove(addition);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    /// <summary>Characters 6 to 8 of a NIFA project number, e.g. CA-D-ARE-2868-H gives ARE.</summary>
    internal static string? NifaDepartmentOf(string? nifaProjectNumber) =>
        nifaProjectNumber is { Length: >= 8 } ? nifaProjectNumber.Substring(5, 3) : null;

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
