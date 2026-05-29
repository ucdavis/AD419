using System.ComponentModel.DataAnnotations;

namespace Server.Core.Domain;

public class User
{
    [Key]
    public int Id { get; set; }

    public Guid EntraId { get; set; }

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(320)]
    public string Email { get; set; } = string.Empty;
}
