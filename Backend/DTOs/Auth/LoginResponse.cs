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
    public string? Telefono { get; set; }
    public string Ruolo { get; set; } = string.Empty;

    /// <summary>Preferenza dell'utente (non del tesserato): null = mai scelta.</summary>
    public bool? TemaScuro { get; set; }

    /// <summary>Colore brand dell'utente "#RRGGBB"; null = mai scelto, "" = verde di default.</summary>
    public string? ColoreBrand { get; set; }
}

public class MeResponse
{
    public PlayerInfo? Player { get; set; }
    public List<TeamMembershipInfo> Teams { get; set; } = new();
}
