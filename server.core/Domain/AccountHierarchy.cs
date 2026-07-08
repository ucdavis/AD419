namespace Server.Core.Domain;

public class AccountHierarchy : ISegmentHierarchy
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
            ("A", ParentLevel0Code, ParentLevel0Name),
            ("B", ParentLevel1Code, ParentLevel1Name),
            ("C", ParentLevel2Code, ParentLevel2Name),
            ("D", ParentLevel3Code, ParentLevel3Name),
            ("E", ParentLevel4Code, ParentLevel4Name),
            ("F", ParentLevel5Code, ParentLevel5Name),
        }
        .Where(l => l.Code is not null)
        .Select(l => new HierarchyLevel(l.Level, l.Code!, l.Name)),
    ];
}
