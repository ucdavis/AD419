namespace Server.Core.Domain;

/// <summary>
/// Read model over [data].[ChartSegments], the AE chart-of-accounts reference
/// data loaded by the segment import. Parent codes are themselves segment
/// rows (same SegmentName), so a breadcrumb can be built by looking each
/// parent code up in the same table.
/// </summary>
public class ChartSegment
{
    public string SegmentName { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int? HierarchyDepth { get; set; }
    public string? ParentLevel0Code { get; set; }
    public string? ParentLevel1Code { get; set; }
    public string? ParentLevel2Code { get; set; }
    public string? ParentLevel3Code { get; set; }
    public string? ParentLevel4Code { get; set; }
    public string? ParentLevel5Code { get; set; }

    public IEnumerable<string> ParentCodes()
    {
        foreach (var code in new[] { ParentLevel0Code, ParentLevel1Code, ParentLevel2Code, ParentLevel3Code, ParentLevel4Code, ParentLevel5Code })
        {
            if (!string.IsNullOrWhiteSpace(code))
            {
                yield return code;
            }
        }
    }

    /// <summary>
    /// The breadcrumb, lettered A (root) downward by level. A level that repeats
    /// this row's own code is a storage artifact of the warehouse's fixed-width
    /// hierarchy format and is left out. Names come from <paramref name="segmentsByCode"/>,
    /// the rows of this same segment.
    /// </summary>
    public IReadOnlyList<HierarchyLevel> Levels(IReadOnlyDictionary<string, ChartSegment> segmentsByCode)
    {
        var codes = new[] { ParentLevel0Code, ParentLevel1Code, ParentLevel2Code, ParentLevel3Code, ParentLevel4Code, ParentLevel5Code };
        var levels = new List<HierarchyLevel>();
        for (var i = 0; i < codes.Length; i++)
        {
            var code = codes[i];
            if (string.IsNullOrWhiteSpace(code) || string.Equals(code, Code, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            levels.Add(new HierarchyLevel(((char)('A' + i)).ToString(), code, segmentsByCode.GetValueOrDefault(code)?.Description));
        }

        return levels;
    }
}
