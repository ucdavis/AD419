namespace Server.Core.Domain;

/// <summary>Read model over [data].[Projects] (built by [data].[BuildProjects]).</summary>
public class Project
{
    public long Id { get; set; }
    public string AccessionNumber { get; set; } = string.Empty;
    public string NifaProjectNumber { get; set; } = string.Empty;
    public string? Title { get; set; }
    public string? ProjectDirector { get; set; }
}
