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
        var projectNumbers = await db.Projects
            .Select(p => p.NifaProjectNumber)
            .ToListAsync(cancellationToken);
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
