namespace CalcioAcinque.Backend.DTOs.Stats;

public class PlayerStatsDto
{
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int PartiteGiocate { get; set; }
    public int PartitePresente { get; set; }
    public int TotaleMinutiGiocati { get; set; }
    public int TotaleGoal { get; set; }
    public int TotaleAssist { get; set; }
    public int TotaleAutogoal { get; set; }
    public int TotaleAmmonizioni { get; set; }
    public int TotaleEspulsioni { get; set; }
    public int TotaleGoalSubiti { get; set; }
    public double MediaGoalPartita { get; set; }
    public double MediaAssistPartita { get; set; }

    // Migliore in campo
    public int VotiMvp { get; set; }
    public int PartiteMvp { get; set; }

    // Affidabilita': come risponde alle convocazioni (solo partite concluse)
    public int ConvocazioniRicevute { get; set; }
    public int ConvocazioniConfermate { get; set; }
    public int Forfait { get; set; }
    public int SenzaRisposta { get; set; }
    /// <summary>Percentuale di convocazioni confermate; null senza convocazioni.</summary>
    public int? Affidabilita { get; set; }
    /// <summary>Ore medie tra convocazione e risposta; null senza risposte.</summary>
    public double? OreMedieRisposta { get; set; }
}

public class TeamStatsDto
{
    public int TeamId { get; set; }

    /// <summary>Stagione su cui sono calcolate; null = tutte (squadre senza stagioni).</summary>
    public int? SeasonId { get; set; }
    public string? SeasonNome { get; set; }

    public int TotalePartite { get; set; }
    public int Vittorie { get; set; }
    public int Pareggi { get; set; }
    public int Sconfitte { get; set; }
    public int TotaleGoal { get; set; }
    public int TotaleAssist { get; set; }
    public int TotaleAutogoal { get; set; }
    public int TotaleAmmonizioni { get; set; }
    public int TotaleEspulsioni { get; set; }
    public int TotaleGoalSubiti { get; set; }
    public List<PlayerStatsDto> Classifica { get; set; } = new();
    public List<MatchStatsDto> StoricoPartite { get; set; } = new();
}

public class MatchStatsDto
{
    public int MatchId { get; set; }
    public int NumeroGiornata { get; set; }
    public DateTime Data { get; set; }
    public int GoalFatti { get; set; }
    public int GoalSubiti { get; set; }
    public int Presenti { get; set; }
}
