namespace CalcioAcinque.Backend.DTOs.Auth;

public class LoginResponse
{
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public DateTime AccessTokenExpiresAt { get; set; }
    public PlayerInfo? Player { get; set; }
    public List<TeamMembershipInfo>? Teams { get; set; }
}

public class PlayerInfo
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int TeamId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string Ruolo { get; set; } = string.Empty;
}
