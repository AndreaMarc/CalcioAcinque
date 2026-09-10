namespace CalcioAcinque.Backend.DTOs.Payments;

public class PlayerPaymentDto
{
    public int Id { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string Descrizione { get; set; } = string.Empty;
    public decimal Importo { get; set; }
    public DateTime DataPagamento { get; set; }
    public bool Pagato { get; set; }
    public string? Note { get; set; }
    public string AdminNome { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    /// <summary>Iscrizione | Tesseramento | Partita | Altro</summary>
    public string Tipo { get; set; } = string.Empty;

    /// <summary>Partita che ha generato l addebito, null per le quote fisse.</summary>
    public int? MatchId { get; set; }

    /// <summary>Non-null = il giocatore ha dichiarato di aver pagato, in attesa di conferma.</summary>
    public DateTime? DichiaratoPagatoAt { get; set; }

    public bool InVerifica => !Pagato && DichiaratoPagatoAt != null;

    /// <summary>Il giocatore non e piu in rosa: la voce resta come traccia contabile.</summary>
    public bool GiocatoreRimosso { get; set; }
}

public class CreatePaymentDto
{
    public string Descrizione { get; set; } = string.Empty;
    public string? Tipo { get; set; }
    public decimal Importo { get; set; }
    public DateTime DataPagamento { get; set; }
    public bool Pagato { get; set; } = false;
    public string? Note { get; set; }
}

public class UpdatePaymentDto
{
    public string? Descrizione { get; set; }
    public decimal? Importo { get; set; }
    public DateTime? DataPagamento { get; set; }
    public bool? Pagato { get; set; }
    public string? Note { get; set; }
}

/// <summary>Genera le quote configurate sulla squadra per tutti i suoi giocatori.</summary>
public class GenerateFeesDto
{
    public bool Iscrizione { get; set; } = true;
    public bool Tesseramento { get; set; } = true;

    /// <summary>Data da mettere sulle voci generate. Default: oggi.</summary>
    public DateTime? Data { get; set; }

    /// <summary>Se vero riallinea l'importo delle quote gia' generate e non ancora pagate.</summary>
    public bool AggiornaEsistenti { get; set; } = false;
}

public class GenerateFeesResultDto
{
    public int Create { get; set; }
    public int Aggiornate { get; set; }
    public int Invariate { get; set; }

    /// <summary>Quote non dovute perche il giocatore paga a partita.</summary>
    public int Esentati { get; set; }
    public decimal TotaleAtteso { get; set; }
    public List<PlayerPaymentDto> Pagamenti { get; set; } = new();
}

/// <summary>Sollecito manuale: lista vuota = tutti quelli che hanno arretrati.</summary>
public class RemindDto
{
    public List<int> PlayerIds { get; set; } = new();
}

public class RemindResultDto
{
    public int Sollecitati { get; set; }
    public int SenzaDispositivo { get; set; }
    public int SenzaArretrati { get; set; }
    public decimal TotaleArretrato { get; set; }
}
