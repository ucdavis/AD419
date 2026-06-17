using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace Server.Core.Domain;

[Index(
    nameof(Dataset),
    nameof(CompletedAt),
    nameof(Id),
    IsDescending = [false, true, true])]
public class ImportLog
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Dataset { get; set; } = string.Empty;

    [Required]
    [MaxLength(260)]
    public string Filename { get; set; } = string.Empty;

    public Guid? UploadedByEntraId { get; set; }

    [MaxLength(200)]
    public string? UploadedByName { get; set; }

    [MaxLength(320)]
    public string? UploadedByEmail { get; set; }

    public DateTimeOffset StartedAt { get; set; }

    public DateTimeOffset CompletedAt { get; set; }

    public int AttemptedRows { get; set; }

    public int? RowsImported { get; set; }

    [Required]
    [MaxLength(32)]
    public string Status { get; set; } = string.Empty;

    public string? ErrorPayload { get; set; }
}
