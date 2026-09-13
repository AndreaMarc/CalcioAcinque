namespace CalcioAcinque.Backend.DTOs.Convocations;

public class ConvocationDto
{
    public int Id { get; set; }
    public int MatchId { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public int? NumeroMaglia { get; set; }
    public string StatoRisposta { get; set; } = string.Empty;
    public DateTime DataConvocazione { get; set; }
    public DateTime? DataRisposta { get; set; }
    public DateTime? DataPartita { get; set; }
    public string? OraPartita { get; set; }
    public string? LuogoPartita { get; set; }
    public int? NumeroGiornata { get; set; }
}

public class SendConvocationsDto
{
    public List<int> PlayerIds { get; set; } = new();
}

public class RespondConvocationDto
{
    public string Risposta { get; set; } = string.Empty;
}
