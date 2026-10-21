using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Core.Domain;
using Server.Helpers;
using Server.Models.SegmentClassifications;

namespace Server.Controllers;

public class SegmentClassificationsController : ApiControllerBase
{
    private readonly DataDbContext _db;

    public SegmentClassificationsController(DataDbContext db)
    {
        _db = db;
    }

    // GET api/segmentclassifications
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<SegmentClassificationDto>>> Get(CancellationToken cancellationToken)
    {
        // Only codes that can still change the report; see v_ClassificationCandidates.
        // The view is read on its own: joined into a larger query, SQL Server
        // can inline it into a far slower plan.
        var candidates = await _db.ClassificationCandidates
            .Select(candidate => new { candidate.SegmentType, candidate.Code })
            .ToListAsync(cancellationToken);
        var candidateKeys = candidates.Select(candidate => ClassificationCandidate.Key(candidate.SegmentType, candidate.Code)).ToHashSet();
        var segments = (await _db.SegmentClassifications.ToListAsync(cancellationToken))
            .Where(segment => candidateKeys.Contains(ClassificationCandidate.Key(segment.SegmentType, segment.Code)))
            .ToList();

        // Hierarchy comes from the AE chart segment reference data. Segment types
        // other than Ern share their name with a ChartSegments SegmentName, and
        // parent codes are rows of the same segment, so their names resolve there too.
        var segmentNames = segments.Select(segment => segment.SegmentType.ToString()).Distinct().ToList();
        var chartSegments = (await _db.ChartSegments
                .Where(chartSegment => segmentNames.Contains(chartSegment.SegmentName))
                .ToListAsync(cancellationToken))
            .GroupBy(chartSegment => chartSegment.SegmentName)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyDictionary<string, ChartSegment>)group.ToDictionary(
                    chartSegment => chartSegment.Code, StringComparer.OrdinalIgnoreCase));

        IReadOnlyList<HierarchyLevelDto> HierarchyFor(SegmentType type, string code)
        {
            var segmentsByCode = chartSegments.GetValueOrDefault(type.ToString());
            var chartSegment = segmentsByCode?.GetValueOrDefault(code);

            return chartSegment is null
                ? []
                : chartSegment.Levels(segmentsByCode!).Select(l => new HierarchyLevelDto(l.Level, l.Code, l.Name)).ToList();
        }

        var dtos = segments
            .OrderBy(segment => segment.SegmentType)
            .ThenBy(segment => segment.Code)
            .Select(segment => new SegmentClassificationDto(
                segment.SegmentType.ToString(),
                segment.Code,
                segment.Description,
                segment.IncludeInReport,
                segment.Sfn,
                HierarchyFor(segment.SegmentType, segment.Code)))
            .ToList();

        return Ok(dtos);
    }

    // PATCH api/segmentclassifications
    [HttpPatch]
    public async Task<IActionResult> UpdateClassification(
        [FromBody] UpdateClassificationRequest request,
        CancellationToken cancellationToken)
    {
        ApiOperationContext.Set(HttpContext,
            ("SegmentType", request.SegmentType), ("Code", request.Code));

        if (!Enum.TryParse<SegmentType>(request.SegmentType, out var segmentType))
        {
            return BadRequest($"Unknown segment type '{request.SegmentType}'.");
        }

        var segment = await _db.SegmentClassifications.FirstOrDefaultAsync(
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
