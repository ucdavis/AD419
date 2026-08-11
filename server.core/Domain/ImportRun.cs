using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Server.Core.Domain;

public static class ImportRunStatus
{
    public const string Running = "Running";
    public const string Succeeded = "Succeeded";
    public const string Failed = "Failed";
}

public class ImportRun
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public DateOnly CycleStart { get; set; }

    public DateOnly CycleEnd { get; set; }

    [Required]
    [MaxLength(32)]
    public string Status { get; set; } = string.Empty;

    public Guid? TriggeredByEntraId { get; set; }

    [MaxLength(200)]
    public string? TriggeredByName { get; set; }

    [MaxLength(320)]
    public string? TriggeredByEmail { get; set; }

    public DateTimeOffset StartedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public List<ImportRunStage> Stages { get; set; } = [];
}
