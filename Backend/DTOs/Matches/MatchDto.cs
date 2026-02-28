namespace CalcioAcinque.Backend.DTOs.Matches;

public class MatchDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public DateTime Data { get; set; }
    public string Ora { get; set; } = string.Empty;
    public string? Luogo { get; set; }
    public string? Titolo { get; set; }
    public int NumeroGiornata { get; set; }
    public string Stato { get; set; } = string.Empty;
    public string? Note { get; set; }
    public int TotaleConvocati { get; set; }
    public int TotaleConfermati { get; set; }
    public int TotalePresenti { get; set; }
    public int TotaleHannoGiocato { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class MatchDetailDto : MatchDto
{
    public List<ConvocationSummaryDto> Convocazioni { get; set; } = new();
    public List<AttendanceSummaryDto> Presenze { get; set; } = new();
}

public class ConvocationSummaryDto
{
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string StatoRisposta { get; set; } = string.Empty;
    public DateTime? DataRisposta { get; set; }
}

public class AttendanceSummaryDto
{
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public bool Convocato { get; set; }
    public bool Presente { get; set; }
    public bool HaGiocato { get; set; }
    public bool GettoneConsumato { get; set; }
}

public class CreateMatchDto
{
    public DateTime Data { get; set; }
    public string Ora { get; set; } = string.Empty;
    public string? Luogo { get; set; }
    public string? Titolo { get; set; }
    public int NumeroGiornata { get; set; }
    public string? Note { get; set; }
}

public class UpdateMatchDto
{
    public DateTime? Data { get; set; }
    public string? Ora { get; set; }
    public string? Luogo { get; set; }
    public string? Titolo { get; set; }
    public int? NumeroGiornata { get; set; }
    public string? Note { get; set; }
}
