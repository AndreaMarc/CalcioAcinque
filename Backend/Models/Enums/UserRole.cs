namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>
/// Ruolo di una persona in UNA squadra: la stessa persona puo' essere mister
/// nell'a7 e semplice giocatore nell'a5. Persistito come stringa: i nuovi valori
/// vanno in coda, quelli esistenti non si rinumerano.
/// </summary>
public enum UserRole
{
    /// <summary>Puo' fare tutto: rosa, campo e cassa.</summary>
    Admin = 0,

    /// <summary>Giocatore: vede e risponde, non amministra.</summary>
    User = 1,

    /// <summary>Partite, convocazioni e presenze. Non vede la cassa.</summary>
    Mister = 2,

    /// <summary>Quote, incassi e solleciti. Non fa formazione.</summary>
    Cassiere = 3
}

/// <summary>
/// Chi puo' fare cosa, in un posto solo. I controller referenziano queste
/// costanti invece di scrivere stringhe di ruoli sparse: cambiare una politica
/// si fa qui e vale per tutti gli endpoint che la usano.
/// </summary>
public static class Ruoli
{
    /// <summary>Rosa, configurazione squadra, societa', inviti. Solo l'admin.</summary>
    public const string Squadra = "Admin";

    /// <summary>Partite, convocazioni, presenze, avvisi in bacheca.</summary>
    public const string Campo = "Admin,Mister";

    /// <summary>Quote, addebiti partita, solleciti.</summary>
    public const string Soldi = "Admin,Cassiere";

    /// <summary>
    /// Rettifica manuale dei gettoni: sta a meta' fra campo e cassa (li consuma
    /// la presenza, ma spesso li ricarica chi incassa), quindi la aprono entrambi.
    /// </summary>
    public const string Gettoni = "Admin,Mister,Cassiere";

    public static string Label(UserRole ruolo) => ruolo switch
    {
        UserRole.Admin => "Amministratore",
        UserRole.Mister => "Mister",
        UserRole.Cassiere => "Cassiere",
        UserRole.User => "Giocatore",
        _ => ruolo.ToString()
    };

    public static string Descrizione(UserRole ruolo) => ruolo switch
    {
        UserRole.Admin => "Rosa, partite e cassa: puo' fare tutto",
        UserRole.Mister => "Partite, convocazioni e presenze. Non vede i pagamenti",
        UserRole.Cassiere => "Quote, incassi e solleciti. Non gestisce le partite",
        UserRole.User => "Vede il suo e risponde alle convocazioni",
        _ => string.Empty
    };

    /// <summary>Chi conta come amministratore della squadra (e quindi della societa').</summary>
    public static bool IsAdmin(UserRole ruolo) => ruolo == UserRole.Admin;

    public static bool PuoGestireCampo(UserRole ruolo) =>
        ruolo is UserRole.Admin or UserRole.Mister;

    public static bool PuoGestireSoldi(UserRole ruolo) =>
        ruolo is UserRole.Admin or UserRole.Cassiere;
}
