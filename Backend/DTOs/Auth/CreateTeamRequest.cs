using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class CreateTeamRequest
{
    [Required, MaxLength(100)]
    public string NomeTeam { get; set; } = string.Empty;

    [Required, MaxLength(100)]
    public string NomeGiocatore { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    /// <summary>Societa' esistente a cui agganciare la squadra. Se null ne viene creata una nuova.</summary>
    public int? ClubId { get; set; }

    /// <summary>Nome della societa' da creare. Se vuoto si usa <see cref="NomeTeam"/>.</summary>
    [MaxLength(100)]
    public string? NomeSocieta { get; set; }

    /// <summary>CalcioA5 | CalcioA7 | CalcioA8 | CalcioA11</summary>
    public string Formato { get; set; } = "CalcioA5";

    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;

    public decimal QuotaIscrizione { get; set; }
    public decimal QuotaTesseramento { get; set; }
    public decimal CostoPartita { get; set; }
}
