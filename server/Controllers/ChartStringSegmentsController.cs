using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.ChartStringSegments;

namespace Server.Controllers;

public class ChartStringSegmentsController : ApiControllerBase
{
    private readonly DataDbContext _db;

    public ChartStringSegmentsController(DataDbContext db)
    {
        _db = db;
    }

    // GET api/chartstringsegments
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ChartStringSegmentDto>>> Get(CancellationToken cancellationToken)
    {
        var segments = await _db.ChartStringSegments.ToListAsync(cancellationToken);

        var departments = await _db.DepartmentHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);
        var accounts = await _db.AccountHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);
        var funds = await _db.FundHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);
        var activities = await _db.ActivityHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);
        var purposes = await _db.PurposeHierarchies.ToDictionaryAsync(h => h.Code, cancellationToken);

        IReadOnlyList<HierarchyLevelDto> HierarchyFor(SegmentType type, string code)
        {
            ISegmentHierarchy? source = type switch
            {
                SegmentType.FinancialDepartment => departments.GetValueOrDefault(code),
                SegmentType.Account => accounts.GetValueOrDefault(code),
                SegmentType.Fund => funds.GetValueOrDefault(code),
                SegmentType.Activity => activities.GetValueOrDefault(code),
                SegmentType.Purpose => purposes.GetValueOrDefault(code),
                _ => null,
            };

            return source is null
                ? []
                : source.Levels().Select(l => new HierarchyLevelDto(l.Level, l.Code, l.Name)).ToList();
        }

        var dtos = segments
            .OrderBy(segment => segment.SegmentType)
            .ThenBy(segment => segment.Code)
            .Select(segment => new ChartStringSegmentDto(
                segment.SegmentType.ToString(),
                segment.Code,
                segment.Description,
                segment.IncludeInReport,
                segment.Sfn,
                HierarchyFor(segment.SegmentType, segment.Code)))
            .ToList();

        return Ok(dtos);
    }

    // PATCH api/chartstringsegments
    [HttpPatch]
    public async Task<IActionResult> UpdateClassification(
        [FromBody] UpdateClassificationRequest request,
        CancellationToken cancellationToken)
    {
        if (!Enum.TryParse<SegmentType>(request.SegmentType, out var segmentType))
        {
            return BadRequest($"Unknown segment type '{request.SegmentType}'.");
        }

        var segment = await _db.ChartStringSegments.FirstOrDefaultAsync(
            candidate => candidate.SegmentType == segmentType && candidate.Code == request.Code,
            cancellationToken);

        if (segment is null)
        {
            return NotFound();
        }

        var isFund = segmentType == SegmentType.Fund;

        if (!isFund && request.Sfn is not null)
        {
            return BadRequest("SFN is only valid for Fund segments.");
        }

        if (isFund && request.IncludeInReport == true && !FundSfns.IsValidForInclusion(request.Sfn))
        {
            return BadRequest($"Invalid SFN '{request.Sfn}' for an included fund.");
        }

        segment.IncludeInReport = request.IncludeInReport;
        segment.Sfn = isFund && request.IncludeInReport == true ? request.Sfn : null;
        await _db.SaveChangesAsync(cancellationToken);

        return NoContent();
    }
}
