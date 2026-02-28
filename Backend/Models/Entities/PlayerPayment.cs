using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("player_payments")]
public class PlayerPayment
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int PlayerId { get; set; }

    [Required, MaxLength(255)]
    public string Descrizione { get; set; } = string.Empty;

    [Column(TypeName = "decimal(10,2)")]
    public decimal Importo { get; set; }

    public DateTime DataPagamento { get; set; }
    public bool Pagato { get; set; } = false;
    public int AdminId { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("PlayerId")]
    public virtual Player Player { get; set; } = null!;

    [ForeignKey("AdminId")]
    public virtual Player Admin { get; set; } = null!;
}
