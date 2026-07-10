using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Server.Core.Domain;

[Index(nameof(IsCurrent))]
public class WorkflowRun
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required]
    [MaxLength(16)]
    public string FiscalYear { get; set; } = string.Empty;

    public DateOnly CycleStart { get; set; }

    public DateOnly CycleEnd { get; set; }

    public bool IsCurrent { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public Guid? CreatedByEntraId { get; set; }

    [MaxLength(200)]
    public string? CreatedByName { get; set; }

    [MaxLength(320)]
    public string? CreatedByEmail { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public Guid? UpdatedByEntraId { get; set; }

    [MaxLength(200)]
    public string? UpdatedByName { get; set; }

    [MaxLength(320)]
    public string? UpdatedByEmail { get; set; }

    public List<WorkflowChecklistItemState> ChecklistItemStates { get; set; } = [];
}
