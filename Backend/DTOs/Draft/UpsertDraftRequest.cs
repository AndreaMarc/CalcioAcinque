using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Draft;

public class UpsertDraftRequest
{
    [Required, MaxLength(100)]
    public string NomeTeam { get; set; } = string.Empty;

    /// <summary>CalcioA5 | CalcioA7 | CalcioA8 | CalcioA11</summary>
    public string Formato { get; set; } = "CalcioA5";

    [Range(1, 50)]
    public int PartitePerStagione { get; set; } = 8;

    [Range(0, 100)]
    public int GettoniPerGiocatore { get; set; } = 4;

    public bool UseGettoni { get; set; } = true;
}
