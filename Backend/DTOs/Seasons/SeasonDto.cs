using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Seasons;

public class SeasonDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public DateTime DataInizio { get; set; }
    public DateTime? DataFine { get; set; }
    public bool Chiusa { get; set; }
    public string? Note { get; set; }

    public int Partite { get; set; }
    public decimal Incassato { get; set; }
    public decimal DaIncassare { get; set; }
}

public class CloseSeasonDto
{
    /// <summary>Se vuoto viene calcolato dall'anno corrente (es. "2026/27").</summary>
    [MaxLength(50)]
    public string? NomeNuovaStagione { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    /// <summary>
    /// Chiudere con dei conti ancora aperti e' quasi sempre un errore, quindi
    /// serve una conferma esplicita: equivale a condonare gli arretrati.
    /// </summary>
    public bool IgnoraArretrati { get; set; }
}

public class CloseSeasonResultDto
{
    public string StagioneChiusa { get; set; } = string.Empty;
    public string StagioneNuova { get; set; } = string.Empty;
    public int GiocatoriAzzerati { get; set; }
    public decimal ArretratiLasciatiAperti { get; set; }
}
