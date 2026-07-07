namespace Server.Core.Domain;

public readonly record struct HierarchyLevel(string Level, string Code, string? Name);

public interface ISegmentHierarchy
{
    string Code { get; }
    string? Description { get; }
    IReadOnlyList<HierarchyLevel> Levels();
}
