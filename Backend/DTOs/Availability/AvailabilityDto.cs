namespace CalcioAcinque.Backend.DTOs.Availability;

public class AvailabilityDto
{
    public int Id { get; set; }
    public int MatchId { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    /// <summary>Falso per lo staff: il client lo mostra a parte.</summary>
    public bool Gioca { get; set; } = true;
    public string Ruolo { get; set; } = string.Empty;
    public bool Disponibile { get; set; }
    public string? Note { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class SetAvailabilityDto
{
    public bool Disponibile { get; set; }
    public string? Note { get; set; }
}

public class MatchAvailabilitySummaryDto
{
    public int MatchId { get; set; }
    public int NumeroGiornata { get; set; }
    public DateTime DataPartita { get; set; }
    public string OraPartita { get; set; } = string.Empty;
    public int Disponibili { get; set; }
    public int NonDisponibili { get; set; }
    public int Totale { get; set; }
    public List<AvailabilityDto> Dettaglio { get; set; } = new();
    public string? MiaDisponibilita { get; set; } // "disponibile", "nonDisponibile", null (non dichiarata)
}
