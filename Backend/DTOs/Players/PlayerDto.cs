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
    /// <summary>Falso per chi e' solo staff e non gioca.</summary>
    public bool Gioca { get; set; } = true;
    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; }
    public int GettoniRimanenti { get; set; }
    public bool IscrizionePagata { get; set; }
    public bool TesseramentoPagato { get; set; }

    /// <summary>Regime scelto per questo giocatore. Null = eredita quello della squadra.</summary>
    public string? RegimePagamento { get; set; }

    /// <summary>Regime che vale davvero, default di squadra risolto.</summary>
    public string RegimePagamentoEffettivo { get; set; } = string.Empty;

    // Eccezioni personali (null = come la squadra) e valori che valgono davvero
    public bool? UsaGettoni { get; set; }
    public bool UsaGettoniEffettivo { get; set; }
    public int? GettoniPerStagione { get; set; }
    public int GettoniPerStagioneEffettivi { get; set; }
    public decimal? QuotaIscrizionePersonale { get; set; }
    public decimal? QuotaTesseramentoPersonale { get; set; }
    public decimal? CostoPartitaPersonale { get; set; }
    public decimal QuotaIscrizioneEffettiva { get; set; }
    public decimal QuotaTesseramentoEffettiva { get; set; }
    public decimal CostoPartitaEffettivo { get; set; }

    /// <summary>Partite in cui e' stato segnato presente (tutte le stagioni).</summary>
    public int Presenze { get; set; }

    /// <summary>Convocazioni ricevute nelle partite concluse (tutte le stagioni).</summary>
    public int ConvocazioniRicevute { get; set; }

    /// <summary>Percentuale di convocazioni confermate; null se mai convocato.</summary>
    public int? Affidabilita { get; set; }

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
    public bool? Gioca { get; set; }
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
    public bool? Gioca { get; set; }
    public bool? IscrizionePagata { get; set; }
    public bool? TesseramentoPagato { get; set; }

    /// <summary>Stringa vuota per tornare al default della squadra.</summary>
    public string? RegimePagamento { get; set; }

    /// <summary>
    /// Eccezioni economiche: il campo `Reimposta*` a true torna al valore della
    /// squadra (null nel JSON non basta: vuol dire "non toccare").
    /// </summary>
    public bool? UsaGettoni { get; set; }
    public bool ReimpostaUsaGettoni { get; set; }
    public int? GettoniPerStagione { get; set; }
    public bool ReimpostaGettoniPerStagione { get; set; }
    public decimal? QuotaIscrizionePersonale { get; set; }
    public bool ReimpostaQuotaIscrizione { get; set; }
    public decimal? QuotaTesseramentoPersonale { get; set; }
    public bool ReimpostaQuotaTesseramento { get; set; }
    public decimal? CostoPartitaPersonale { get; set; }
    public bool ReimpostaCostoPartita { get; set; }
}

public class ResetPasswordDto
{
    [System.ComponentModel.DataAnnotations.Required]
    [System.ComponentModel.DataAnnotations.MinLength(6)]
    [System.ComponentModel.DataAnnotations.MaxLength(100)]
    public string NewPassword { get; set; } = string.Empty;
}
