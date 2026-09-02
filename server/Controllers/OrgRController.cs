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

    private static string? NormalizeCode(string? code)
    {
        var trimmed = code?.Trim().ToUpperInvariant();
        return trimmed is not null && OrgRCodePattern().IsMatch(trimmed) ? trimmed : null;
    }

    private async Task<bool> OrgRExistsAsync(string code, CancellationToken cancellationToken) =>
        await db.OrgRs.AnyAsync(o => o.Code == code, cancellationToken);
}
