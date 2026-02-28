using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class CreateTeamRequest
{
    [Required, MaxLength(100)]
    public string NomeTeam { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string NomeGiocatore { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;
}
