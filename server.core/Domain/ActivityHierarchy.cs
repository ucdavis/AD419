namespace Server.Core.Domain;

public class ActivityHierarchy : ISegmentHierarchy
{
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? ParentLevel0Code { get; set; }
    public string? ParentLevel0Name { get; set; }
    public string? ParentLevel1Code { get; set; }
    public string? ParentLevel1Name { get; set; }
    public string? ParentLevel2Code { get; set; }
    public string? ParentLevel2Name { get; set; }
    public string? ParentLevel3Code { get; set; }
    public string? ParentLevel3Name { get; set; }
    public string? ParentLevel4Code { get; set; }
    public string? ParentLevel4Name { get; set; }
    public string? ParentLevel5Code { get; set; }
    public string? ParentLevel5Name { get; set; }

    public IReadOnlyList<HierarchyLevel> Levels() =>
    [
        .. new (string Level, string? Code, string? Name)[]
        {
            ("0", ParentLevel0Code, ParentLevel0Name),
            ("1", ParentLevel1Code, ParentLevel1Name),
            ("2", ParentLevel2Code, ParentLevel2Name),
            ("3", ParentLevel3Code, ParentLevel3Name),
            ("4", ParentLevel4Code, ParentLevel4Name),
            ("5", ParentLevel5Code, ParentLevel5Name),
        }
        .Where(l => l.Code is not null)
        .Select(l => new HierarchyLevel(l.Level, l.Code!, l.Name)),
    ];
}
