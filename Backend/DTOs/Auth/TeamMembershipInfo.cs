namespace CalcioAcinque.Backend.DTOs.Auth;

public class TeamMembershipInfo
{
    public int TeamId { get; set; }
    public int PlayerId { get; set; }
    public string TeamName { get; set; } = string.Empty;
    public string Ruolo { get; set; } = string.Empty;
}
