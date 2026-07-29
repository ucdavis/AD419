using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Server.Core.Domain;

public static class ImportStageStatus
{
    public const string Pending = "Pending";
    public const string Running = "Running";
    public const string Succeeded = "Succeeded";
    public const string Failed = "Failed";
}

public class ImportRunStage
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int ImportRunId { get; set; }

    public ImportRun? ImportRun { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public int Ordinal { get; set; }

    [Required]
    [MaxLength(32)]
    public string Status { get; set; } = string.Empty;

    public int? RowCount { get; set; }

    public DateTimeOffset? StartedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    public string? ErrorDetail { get; set; }
}
