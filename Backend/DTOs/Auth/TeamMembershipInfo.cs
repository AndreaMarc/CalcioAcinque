namespace CalcioAcinque.Backend.DTOs.Auth;

public class TeamMembershipInfo
{
    public int TeamId { get; set; }
    public int PlayerId { get; set; }
    public string TeamName { get; set; } = string.Empty;
    public string Ruolo { get; set; } = string.Empty;

    public int? ClubId { get; set; }
    public string? ClubName { get; set; }

    /// <summary>CalcioA5 | CalcioA7 | CalcioA8 | CalcioA11</summary>
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public string FormatoShortLabel { get; set; } = string.Empty;
}
