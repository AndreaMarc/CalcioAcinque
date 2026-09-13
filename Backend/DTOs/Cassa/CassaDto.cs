using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Cassa;

public class TeamExpenseDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public int? SeasonId { get; set; }
    public int? MatchId { get; set; }
    public string Categoria { get; set; } = string.Empty;
    public string CategoriaLabel { get; set; } = string.Empty;
    public string Descrizione { get; set; } = string.Empty;
    public decimal Importo { get; set; }
    public DateTime Data { get; set; }
    public string? Note { get; set; }
    public string? AdminNome { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UpsertExpenseDto
{
    public string Categoria { get; set; } = "Altro";

    [Required, MaxLength(200)]
    public string Descrizione { get; set; } = string.Empty;

    [Range(0.01, 100000)]
    public decimal Importo { get; set; }

    /// <summary>Default: oggi.</summary>
    public DateTime? Data { get; set; }

    public int? MatchId { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }
}

/// <summary>Il cruscotto del cassiere: quanto e' entrato, quanto e' uscito, cosa manca.</summary>
public class CassaSummaryDto
{
    public int? SeasonId { get; set; }
    public string? SeasonNome { get; set; }

    public decimal EntrateAttese { get; set; }
    public decimal EntrateIncassate { get; set; }
    public decimal InVerifica { get; set; }
    public decimal Uscite { get; set; }

    /// <summary>Incassato meno uscite: i soldi che ci sono davvero.</summary>
    public decimal Saldo { get; set; }

    public List<PartitaNonIncassataDto> PartiteNonIncassate { get; set; } = new();
    public List<ArretratoDto> Arretrati { get; set; } = new();
    public List<UscitaCategoriaDto> UscitePerCategoria { get; set; } = new();
}

public class PartitaNonIncassataDto
{
    public int MatchId { get; set; }
    public int NumeroGiornata { get; set; }
    public DateTime Data { get; set; }
    public string? Titolo { get; set; }
    public int Presenti { get; set; }
    /// <summary>Presenti che pagano a partita: se e' zero non c'e' nulla da incassare.</summary>
    public int PresentiAPartita { get; set; }
}

public class ArretratoDto
{
    public int PlayerId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public decimal Importo { get; set; }
    public int Voci { get; set; }
}

public class UscitaCategoriaDto
{
    public string Categoria { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public decimal Importo { get; set; }
}
