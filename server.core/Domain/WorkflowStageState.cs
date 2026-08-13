using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Server.Core.Domain;

public static class WorkflowStageStatus
{
    public const string NotStarted = "NotStarted";
    public const string InProgress = "InProgress";
    public const string Complete = "Complete";
}

[Index(nameof(WorkflowRunId), nameof(StageId), IsUnique = true)]
public class WorkflowStageState
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int WorkflowRunId { get; set; }

    public WorkflowRun WorkflowRun { get; set; } = null!;

    [Required]
    [MaxLength(80)]
    public string StageId { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string Status { get; set; } = WorkflowStageStatus.NotStarted;

    public DateTimeOffset? StartedAt { get; set; }

    public Guid? StartedByEntraId { get; set; }

    [MaxLength(200)]
    public string? StartedByName { get; set; }

    [MaxLength(320)]
    public string? StartedByEmail { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public Guid? CompletedByEntraId { get; set; }

    [MaxLength(200)]
    public string? CompletedByName { get; set; }

    [MaxLength(320)]
    public string? CompletedByEmail { get; set; }
}
