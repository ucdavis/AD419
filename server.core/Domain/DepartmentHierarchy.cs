namespace Server.Core.Domain;

public class DepartmentHierarchy : ISegmentHierarchy
{
    public string Code { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? ParentLevelACode { get; set; }
    public string? ParentLevelAName { get; set; }
    public string? ParentLevelBCode { get; set; }
    public string? ParentLevelBName { get; set; }
    public string? ParentLevelCCode { get; set; }
    public string? ParentLevelCName { get; set; }
    public string? ParentLevelDCode { get; set; }
    public string? ParentLevelDName { get; set; }
    public string? ParentLevelECode { get; set; }
    public string? ParentLevelEName { get; set; }
    public string? ParentLevelFCode { get; set; }
    public string? ParentLevelFName { get; set; }
    public string? ParentLevelGCode { get; set; }
    public string? ParentLevelGName { get; set; }

    public IReadOnlyList<HierarchyLevel> Levels() =>
    [
        .. new (string Level, string? Code, string? Name)[]
        {
            ("A", ParentLevelACode, ParentLevelAName),
            ("B", ParentLevelBCode, ParentLevelBName),
            ("C", ParentLevelCCode, ParentLevelCName),
            ("D", ParentLevelDCode, ParentLevelDName),
            ("E", ParentLevelECode, ParentLevelEName),
            ("F", ParentLevelFCode, ParentLevelFName),
            ("G", ParentLevelGCode, ParentLevelGName),
        }
        .Where(l => l.Code is not null)
        .Select(l => new HierarchyLevel(l.Level, l.Code!, l.Name)),
    ];
}
