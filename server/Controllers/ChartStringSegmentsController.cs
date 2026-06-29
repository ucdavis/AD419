using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Models.ChartStringSegments;

namespace Server.Controllers;

public class ChartStringSegmentsController : ApiControllerBase
{
    private readonly AppDbContext _db;

    public ChartStringSegmentsController(AppDbContext db)
    {
        _db = db;
    }

    // GET api/chartstringsegments
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ChartStringSegmentDto>>> Get(CancellationToken cancellationToken)
    {
        var segments = await _db.ChartStringSegments.ToListAsync(cancellationToken);

        var dtos = segments
            .OrderBy(segment => segment.SegmentType)
            .ThenBy(segment => segment.Code)
            .Select(segment => new ChartStringSegmentDto(
                segment.SegmentType.ToString(),
                segment.Code,
                segment.Description,
                segment.IncludeInReport,
                segment.Sfn))
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

        segment.IncludeInReport = request.IncludeInReport;
        await _db.SaveChangesAsync(cancellationToken);

        return NoContent();
    }
}
