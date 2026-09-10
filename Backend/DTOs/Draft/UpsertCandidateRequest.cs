using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Draft;

public class UpsertCandidateRequest
{
    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    /// <summary>Portiere | Difensore | Centrocampista | Attaccante | Jolly</summary>
    public string? Posizione { get; set; }

    /// <summary>Confermato | InForse | DaSentire | Rifiutato</summary>
    [Required]
    public string Stato { get; set; } = "DaSentire";

    [Range(1, 5)]
    public int Bravura { get; set; } = 3;

    [Range(1, 5)]
    public int Affidabilita { get; set; } = 3;

    public bool Tesserato { get; set; } = false;

    [MaxLength(500)]
    public string? Note { get; set; }
}
