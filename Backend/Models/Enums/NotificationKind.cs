namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>
/// Tipi di notifica push. Persistiti come stringa: aggiungere in coda,
/// mai rinumerare i valori esistenti.
/// </summary>
public enum NotificationKind
{
    /// <summary>Sei stato convocato per una partita.</summary>
    Convocazione = 0,

    /// <summary>Nuovo avviso in bacheca.</summary>
    Avviso = 1,

    /// <summary>Data, ora o luogo di una partita sono cambiati.</summary>
    PartitaAggiornata = 2,

    /// <summary>Notifica di prova, inviata solo su richiesta esplicita.</summary>
    Prova = 3,

    /// <summary>Hai una quota o un addebito partita da saldare.</summary>
    PagamentoDovuto = 4,

    /// <summary>Si gioca a breve: promemoria per i convocati.</summary>
    PromemoriaPartita = 5,

    /// <summary>Un convocato ha dato forfait: avviso a mister e admin.</summary>
    Forfait = 6,

    /// <summary>Riepilogo settimanale della cassa per chi la tiene.</summary>
    RiepilogoCassa = 7
}

public enum NotificationStatus
{
    InCoda = 0,
    Inviata = 1,
    Fallita = 2
}

public static class NotificationKinds
{
    /// <summary>Tipi che l'utente puo' accendere o spegnere dalle impostazioni.</summary>
    public static readonly IReadOnlyList<NotificationKind> Configurabili = new[]
    {
        NotificationKind.Convocazione,
        NotificationKind.Avviso,
        NotificationKind.PartitaAggiornata,
        NotificationKind.PagamentoDovuto,
        NotificationKind.PromemoriaPartita,
        NotificationKind.Forfait,
        NotificationKind.RiepilogoCassa
    };

    public static string Label(NotificationKind kind) => kind switch
    {
        NotificationKind.Convocazione => "Convocazioni",
        NotificationKind.Avviso => "Avvisi in bacheca",
        NotificationKind.PartitaAggiornata => "Partite modificate",
        NotificationKind.PagamentoDovuto => "Pagamenti da saldare",
        NotificationKind.PromemoriaPartita => "Promemoria partita",
        NotificationKind.Forfait => "Forfait dei convocati",
        NotificationKind.RiepilogoCassa => "Riepilogo cassa",
        NotificationKind.Prova => "Notifica di prova",
        _ => kind.ToString()
    };

    public static string Descrizione(NotificationKind kind) => kind switch
    {
        NotificationKind.Convocazione => "Quando vieni convocato per una partita",
        NotificationKind.Avviso => "Quando viene pubblicato un avviso",
        NotificationKind.PartitaAggiornata => "Quando cambia data, ora o campo",
        NotificationKind.PagamentoDovuto => "Quando hai una quota o una partita da pagare",
        NotificationKind.PromemoriaPartita => "Poco prima della partita, per ricordartela",
        NotificationKind.Forfait => "Solo mister e admin: quando un convocato dice di no, con i sostituti disponibili",
        NotificationKind.RiepilogoCassa => "Solo cassiere e admin: il lunedi', cosa manca da incassare",
        _ => string.Empty
    };
}
