namespace CalcioAcinque.Backend.DTOs.Tokens;

public class TokenTransactionDto
{
    public int Id { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public int? MatchId { get; set; }
    public int? NumeroGiornata { get; set; }
    public string Tipo { get; set; } = string.Empty;
    public string Motivazione { get; set; } = string.Empty;
    public int Quantita { get; set; }
    public string AdminNome { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
}

public class ManualTokenDto
{
    public int Quantita { get; set; }
    public string Motivazione { get; set; } = string.Empty;
    public int? MatchId { get; set; }
}

public class PlayerTokenSummaryDto
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; }
    public int GettoniRimanenti { get; set; }
}
