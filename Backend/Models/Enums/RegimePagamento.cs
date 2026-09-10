namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>
/// Come un giocatore contribuisce ai costi della squadra. Persistito come stringa:
/// aggiungere in coda, mai rinumerare i valori esistenti.
/// </summary>
public enum RegimePagamento
{
    /// <summary>Paga la quota all'inizio e poi non riceve addebiti per le singole partite.</summary>
    Stagionale = 0,

    /// <summary>Nessuna quota stagionale: riceve un addebito per ogni partita giocata.</summary>
    APartita = 1
}

/// <summary>A chi si applica una quota fissa (iscrizione, tesseramento).</summary>
public enum DestinatariQuota
{
    /// <summary>Tutti i giocatori in rosa, qualunque sia il loro regime.</summary>
    Tutti = 0,

    /// <summary>Solo chi paga a stagione: chi paga a partita ne e' esentato.</summary>
    SoloStagionali = 1
}

/// <summary>
/// Natura di una voce di pagamento. Serve a distinguere le quote fisse dagli
/// addebiti partita nei filtri e nei totali, senza dover interpretare la descrizione.
/// </summary>
public enum TipoPagamento
{
    Iscrizione = 0,
    Tesseramento = 1,
    Partita = 2,
    Altro = 3
}

public static class RegimiPagamento
{
    public static string Label(RegimePagamento regime) => regime switch
    {
        RegimePagamento.Stagionale => "Quota stagionale",
        RegimePagamento.APartita => "Paga a partita",
        _ => regime.ToString()
    };

    public static string Descrizione(RegimePagamento regime) => regime switch
    {
        RegimePagamento.Stagionale => "Versa la quota all'inizio, poi non paga le singole partite",
        RegimePagamento.APartita => "Riceve un addebito dopo ogni partita giocata",
        _ => string.Empty
    };

    /// <summary>
    /// Regime effettivo di un giocatore: se non ne ha uno proprio vale il default
    /// della squadra. E' il punto unico in cui si risolve questa ereditarieta'.
    /// </summary>
    public static RegimePagamento Effettivo(RegimePagamento? delGiocatore, RegimePagamento defaultSquadra) =>
        delGiocatore ?? defaultSquadra;

    /// <summary>Vero se una quota fissa con questi destinatari e' dovuta da chi ha quel regime.</summary>
    public static bool QuotaDovuta(DestinatariQuota destinatari, RegimePagamento regime) =>
        destinatari == DestinatariQuota.Tutti || regime == RegimePagamento.Stagionale;
}
