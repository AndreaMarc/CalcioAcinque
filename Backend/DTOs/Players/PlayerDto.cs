namespace CalcioAcinque.Backend.DTOs.Players;

public class PlayerDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public int UserId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string Ruolo { get; set; } = string.Empty;
    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; }
    public int GettoniRimanenti { get; set; }
    public bool IscrizionePagata { get; set; }
    public bool TesseramentoPagato { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class PlayerDetailDto : PlayerDto
{
    public string Email { get; set; } = string.Empty;
    public int PartiteConvocato { get; set; }
    public int PartitePresente { get; set; }
    public int PartiteGiocate { get; set; }
}

public class CreatePlayerDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string Ruolo { get; set; } = "User";
}

public class UpdatePlayerDto
{
    public string? Nome { get; set; }
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string? Ruolo { get; set; }
    public bool? IscrizionePagata { get; set; }
    public bool? TesseramentoPagato { get; set; }
}

public class ResetPasswordDto
{
    public string NewPassword { get; set; } = string.Empty;
}
