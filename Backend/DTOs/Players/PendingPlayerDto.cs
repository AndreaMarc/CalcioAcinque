namespace CalcioAcinque.Backend.DTOs.Players;

public class PendingPlayerDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Posizione { get; set; }
    public int Bravura { get; set; }
    public int Affidabilita { get; set; }
    public bool Tesserato { get; set; }
    public string? Note { get; set; }
}

public class JoinInfoResponse
{
    /// <summary>Nome della squadra quando il codice e' di una singola squadra, altrimenti vuoto.</summary>
    public string TeamName { get; set; } = string.Empty;

    /// <summary>"team" se il codice appartiene a una squadra, "club" se e' il codice della societa'.</summary>
    public string CodeType { get; set; } = "team";

    public int? ClubId { get; set; }
    public string? ClubName { get; set; }

    /// <summary>Squadre selezionabili: una sola per un codice squadra, tutte quelle della societa' per un codice societa'.</summary>
    public List<JoinTeamOption> Teams { get; set; } = new();

    public List<PendingPlayerDto> PendingPlayers { get; set; } = new();
}

public class JoinTeamOption
{
    public int TeamId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public int TotaleGiocatori { get; set; }
    public List<PendingPlayerDto> PendingPlayers { get; set; } = new();
}
