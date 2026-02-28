using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class JoinTeamRequest
{
    [Required]
    public string InviteCode { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }
}
