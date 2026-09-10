using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("token_transactions")]
public class TokenTransaction
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int PlayerId { get; set; }
    public int? MatchId { get; set; }

    [Required]
    public TipoTransazione Tipo { get; set; }

    [Required, MaxLength(500)]
    public string Motivazione { get; set; } = string.Empty;

    public int Quantita { get; set; }

    /// <summary>
    /// Chi ha registrato il movimento. Nullable perche' l'admin puo' lasciare la
    /// squadra: il movimento resta, con il nome congelato in <see cref="AdminNome"/>.
    /// </summary>
    public int? AdminId { get; set; }

    [Required, MaxLength(100)]
    public string AdminNome { get; set; } = string.Empty;

    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    [ForeignKey("PlayerId")]
    public virtual Player Player { get; set; } = null!;

    [ForeignKey("MatchId")]
    public virtual Match? Match { get; set; }

    [ForeignKey("AdminId")]
    public virtual Player? Admin { get; set; }
}
