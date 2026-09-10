namespace CalcioAcinque.Backend.DTOs.Dashboard;

public class DashboardDto
{
    public MatchSummaryDto? ProssimaPartita { get; set; }
    public bool UseGettoni { get; set; } = true;

    // Contesto squadra: serve al client per etichette e conteggi coerenti col formato
    public string TeamNome { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public string FormatoShortLabel { get; set; } = string.Empty;
    public int GiocatoriInCampo { get; set; }
    public int? MaxConvocati { get; set; }
    public int? ClubId { get; set; }
    public string? ClubNome { get; set; }
    public int GettoniRimanenti { get; set; }
    public int GettoniTotali { get; set; }
    public int ConvocazioniInAttesa { get; set; }
    public int PartiteGiocate { get; set; }
    public int PartiteTotali { get; set; }
    public List<PlayerTokenSummaryForDashboard> ClassificaGettoni { get; set; } = new();
}

public class MatchSummaryDto
{
    public int Id { get; set; }
    public DateTime Data { get; set; }
    public string Ora { get; set; } = string.Empty;
    public string? Luogo { get; set; }
    public string? Titolo { get; set; }
    public int NumeroGiornata { get; set; }
    public string Stato { get; set; } = string.Empty;
    public int Confermati { get; set; }
    public int InAttesa { get; set; }
    public int NonDisponibili { get; set; }
    public string? MiaConvocazione { get; set; }  // null = non convocato, "InAttesa", "Confermato", "NonDisponibile"
}

public class PlayerTokenSummaryForDashboard
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int GettoniRimanenti { get; set; }
    public int GettoniTotali { get; set; }
}
