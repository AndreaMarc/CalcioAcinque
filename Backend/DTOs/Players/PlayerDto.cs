namespace CalcioAcinque.Backend.DTOs.Players;

public class PlayerDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public int UserId { get; set; }
    public int? ClubMemberId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string Ruolo { get; set; } = string.Empty;
    public string? Posizione { get; set; }
    public int? NumeroMaglia { get; set; }
    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; }
    public int GettoniRimanenti { get; set; }
    public bool IscrizionePagata { get; set; }
    public bool TesseramentoPagato { get; set; }

    /// <summary>Regime scelto per questo giocatore. Null = eredita quello della squadra.</summary>
    public string? RegimePagamento { get; set; }

    /// <summary>Regime che vale davvero, default di squadra risolto.</summary>
    public string RegimePagamentoEffettivo { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}

public class PlayerDetailDto : PlayerDto
{
    public string Email { get; set; } = string.Empty;
    public int PartiteConvocato { get; set; }
    public int PartitePresente { get; set; }
    public int PartiteGiocate { get; set; }
    /// <summary>Le altre squadre della societa' in cui gioca la stessa persona.</summary>
    public List<PlayerOtherTeamDto> AltreSquadre { get; set; } = new();
}

public class PlayerOtherTeamDto
{
    public int TeamId { get; set; }
    public int PlayerId { get; set; }
    public string TeamNome { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoShortLabel { get; set; } = string.Empty;
    public string? Posizione { get; set; }
}

public class CreatePlayerDto
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string Ruolo { get; set; } = "User";
    public string? Posizione { get; set; }
    public int? NumeroMaglia { get; set; }
    public string? RegimePagamento { get; set; }
}

public class UpdatePlayerDto
{
    public string? Nome { get; set; }
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public string? Ruolo { get; set; }
    public string? Posizione { get; set; }
    public int? NumeroMaglia { get; set; }
    public bool? IscrizionePagata { get; set; }
    public bool? TesseramentoPagato { get; set; }

    /// <summary>Stringa vuota per tornare al default della squadra.</summary>
    public string? RegimePagamento { get; set; }
}

public class ResetPasswordDto
{
    [System.ComponentModel.DataAnnotations.Required]
    [System.ComponentModel.DataAnnotations.MinLength(6)]
    [System.ComponentModel.DataAnnotations.MaxLength(100)]
    public string NewPassword { get; set; } = string.Empty;
}
