using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Server.Core.Domain;

[Index(nameof(WorkflowRunId), nameof(ItemId), IsUnique = true)]
public class WorkflowChecklistItemState
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int WorkflowRunId { get; set; }

    public WorkflowRun WorkflowRun { get; set; } = null!;

    [Required]
    [MaxLength(80)]
    public string ItemId { get; set; } = string.Empty;

    public DateTimeOffset? CompletedAt { get; set; }

    public Guid? CompletedByEntraId { get; set; }

    [MaxLength(200)]
    public string? CompletedByName { get; set; }

    [MaxLength(320)]
    public string? CompletedByEmail { get; set; }

    public int? SourceImportLogId { get; set; }

    public ImportLog? SourceImportLog { get; set; }

    [MaxLength(160)]
    public string? SourceKey { get; set; }

    public int? SourceRows { get; set; }

    public DateTimeOffset? SourceCompletedAt { get; set; }
}
