namespace CalcioAcinque.Backend.DTOs.Teams;

public class TeamDto
{
    public int Id { get; set; }
    public int? ClubId { get; set; }
    public string? ClubNome { get; set; }
    public string Nome { get; set; } = string.Empty;

    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public string FormatoShortLabel { get; set; } = string.Empty;

    public int PartitePerStagione { get; set; }
    public int GettoniPerGiocatore { get; set; }
    public bool UseGettoni { get; set; }

    public int GiocatoriInCampo { get; set; }
    public int? MaxConvocati { get; set; }
    public int MinutiPerTempo { get; set; }
    public int NumeroTempi { get; set; }

    public decimal QuotaIscrizione { get; set; }
    public decimal QuotaTesseramento { get; set; }
    public decimal CostoPartita { get; set; }

    /// <summary>Stagionale | APartita: regime dei giocatori che non ne hanno uno proprio.</summary>
    public string RegimePagamentoDefault { get; set; } = string.Empty;

    /// <summary>Tutti | SoloStagionali</summary>
    public string ApplicaIscrizioneA { get; set; } = string.Empty;
    public string ApplicaTesseramentoA { get; set; } = string.Empty;

    public int MinutiMinimiPerAddebito { get; set; }

    /// <summary>Ore prima della partita per il promemoria. 0 = spento.</summary>
    public int OrePromemoriaPartita { get; set; }

    // Override della squadra: null = si usano quelli della societa
    public string? PaypalLink { get; set; }
    public string? Iban { get; set; }
    public string? IntestatarioIban { get; set; }

    // Valori efficaci (squadra ?? societa): il client usa questi e non risolve nulla
    public string? PaypalLinkEffettivo { get; set; }
    public string? IbanEffettivo { get; set; }
    public string? IntestatarioIbanEffettivo { get; set; }

    public int TotaleGiocatori { get; set; }
    public DateTime CreatedAt { get; set; }

    /// <summary>Logo condiviso della squadra (base64), null se non caricato.</summary>
    public string? LogoBase64 { get; set; }
}

public class CreateTeamDto
{
    public string Nome { get; set; } = string.Empty;
    public string Formato { get; set; } = "CalcioA5";
    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;
    public decimal QuotaIscrizione { get; set; }
    public decimal QuotaTesseramento { get; set; }
    public decimal CostoPartita { get; set; }
}

public class UpdateTeamDto
{
    public string? Nome { get; set; }
    /// <summary>Cambiare formato riallinea le regole ai default del nuovo formato,
    /// salvo quelle passate esplicitamente in questa stessa richiesta.</summary>
    public string? Formato { get; set; }
    public int? PartitePerStagione { get; set; }
    public int? GettoniPerGiocatore { get; set; }
    public bool? UseGettoni { get; set; }

    public int? GiocatoriInCampo { get; set; }
    public int? MaxConvocati { get; set; }
    public int? MinutiPerTempo { get; set; }
    public int? NumeroTempi { get; set; }

    public decimal? QuotaIscrizione { get; set; }
    public decimal? QuotaTesseramento { get; set; }
    public decimal? CostoPartita { get; set; }

    public string? RegimePagamentoDefault { get; set; }
    public string? ApplicaIscrizioneA { get; set; }
    public string? ApplicaTesseramentoA { get; set; }
    public int? MinutiMinimiPerAddebito { get; set; }
    public int? OrePromemoriaPartita { get; set; }

    /// <summary>Stringa vuota per azzerare l override e tornare ai dati della societa.</summary>
    public string? PaypalLink { get; set; }
    public string? Iban { get; set; }
    public string? IntestatarioIban { get; set; }

    /// <summary>Logo in base64; stringa vuota per rimuoverlo, null per non toccarlo.</summary>
    public string? LogoBase64 { get; set; }
}
