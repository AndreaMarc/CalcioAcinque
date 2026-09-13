using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Un'uscita di cassa della squadra: affitto campo, arbitro, palloni.
/// Prima la cassa registrava solo entrate e il saldo vero stava su un foglio a parte.
/// </summary>
[Table("team_expenses")]
public class TeamExpense
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TeamId { get; set; }

    /// <summary>Stagione a cui appartiene, per l'archivio.</summary>
    public int? SeasonId { get; set; }

    /// <summary>Partita a cui si riferisce (affitto campo, arbitro), se c'e'.</summary>
    public int? MatchId { get; set; }

    public CategoriaSpesa Categoria { get; set; } = CategoriaSpesa.Altro;

    [Required, MaxLength(200)]
    public string Descrizione { get; set; } = string.Empty;

    [Column(TypeName = "decimal(10,2)")]
    public decimal Importo { get; set; }

    public DateTime Data { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    /// <summary>Chi l'ha registrata; il nome e' congelato perche' l'admin puo' uscire dalla rosa.</summary>
    public int? AdminId { get; set; }

    [MaxLength(100)]
    public string? AdminNome { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("SeasonId")]
    public virtual Season? Season { get; set; }

    [ForeignKey("MatchId")]
    public virtual Match? Match { get; set; }
}
