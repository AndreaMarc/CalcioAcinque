namespace CalcioAcinque.Backend.DTOs.Mvp;

public class MatchMvpDto
{
    public int MatchId { get; set; }

    /// <summary>Si vota solo a partita conclusa.</summary>
    public bool Aperto { get; set; }

    /// <summary>Il voto di chi guarda, se l'ha gia' dato.</summary>
    public int? MioVotoPlayerId { get; set; }

    public int TotaleVoti { get; set; }
    public List<MvpVoteCountDto> Classifica { get; set; } = new();

    /// <summary>Chi si puo' votare: i presenti alla partita.</summary>
    public List<MvpCandidateDto> Candidati { get; set; } = new();
}

public class MvpVoteCountDto
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int Voti { get; set; }
}

public class MvpCandidateDto
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int? NumeroMaglia { get; set; }
}

public class VoteMvpDto
{
    public int PlayerId { get; set; }
}
