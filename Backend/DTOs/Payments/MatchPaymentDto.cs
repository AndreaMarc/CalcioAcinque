using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Payments;

/// <summary>Cosa l'admin vede prima di decidere a chi addebitare la partita.</summary>
public class MatchPaymentPreviewDto
{
    public int MatchId { get; set; }
    public string Partita { get; set; } = string.Empty;
    public DateTime Data { get; set; }
    public string Stato { get; set; } = string.Empty;

    /// <summary>Importo proposto per ogni giocatore, da <c>Team.CostoPartita</c>.</summary>
    public decimal CostoPartita { get; set; }

    public int MinutiMinimiPerAddebito { get; set; }

    /// <summary>Vero se per questa partita e' gia' stato registrato almeno un addebito.</summary>
    public bool GiaGestita { get; set; }

    /// <summary>
    /// Nessuna presenza registrata: la lista sara' vuota e il client deve dirlo,
    /// non mostrare un elenco vuoto senza spiegazione.
    /// </summary>
    public bool PresenzeDaRegistrare { get; set; }

    /// <summary>Vero se la partita e' conclusa, quindi le presenze sono in sola lettura.</summary>
    public bool PresenzeBloccate { get; set; }

    /// <summary>Spesa campo gia' registrata per la partita, se c'e'.</summary>
    public decimal? SpesaCampoRegistrata { get; set; }

    public List<MatchPaymentCandidateDto> Candidati { get; set; } = new();
}

public class MatchPaymentCandidateDto
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }

    /// <summary>Stagionale | APartita (regime effettivo, default di squadra incluso).</summary>
    public string Regime { get; set; } = string.Empty;

    public bool Presente { get; set; }
    public bool HaGiocato { get; set; }
    public int? MinutiGiocati { get; set; }

    /// <summary>Preselezionato nella UI. L'admin resta libero di cambiare.</summary>
    public bool Preselezionato { get; set; }

    /// <summary>Esiste gia' un pagamento per questa partita: non va addebitato di nuovo.</summary>
    public bool GiaAddebitato { get; set; }

    /// <summary>Perche' non e' preselezionato, da mostrare accanto al nome.</summary>
    public string? Motivo { get; set; }

    public decimal ImportoProposto { get; set; }

    /// <summary>Quanto questa persona deve gia' alla squadra, quote incluse.</summary>
    public decimal ArretratoAttuale { get; set; }
}

public class ConfirmMatchPaymentDto
{
    /// <summary>Chi addebitare. Chi e' gia' stato addebitato viene ignorato senza errore.</summary>
    [Required]
    public List<int> PlayerIds { get; set; } = new();

    /// <summary>Importo unico per tutti. Se assente si usa <c>Team.CostoPartita</c>.</summary>
    public decimal? Importo { get; set; }

    /// <summary>Importi diversi per singolo giocatore, hanno la precedenza su <see cref="Importo"/>.</summary>
    public Dictionary<int, decimal>? ImportiPerGiocatore { get; set; }

    public bool InviaNotifica { get; set; } = true;

    /// <summary>Costo totale del campo per questa partita: viene registrato come uscita.</summary>
    public decimal? SpesaCampo { get; set; }

    /// <summary>Se vero, l'importo a testa e' la spesa campo divisa tra i selezionati (arrotondata a 50 cent).</summary>
    public bool DividiSpesaCampo { get; set; }
}

public class ConfirmMatchPaymentResultDto
{
    public int Addebitati { get; set; }
    public int Saltati { get; set; }
    public int NotificheAccodate { get; set; }
    public decimal TotaleAddebitato { get; set; }
    public List<PlayerPaymentDto> Pagamenti { get; set; } = new();
}
