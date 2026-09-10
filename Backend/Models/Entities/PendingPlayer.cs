using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("pending_players")]
public class PendingPlayer
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    public PlayerPosition? Posizione { get; set; }

    [Range(1, 5)]
    public int Bravura { get; set; } = 3;

    [Range(1, 5)]
    public int Affidabilita { get; set; } = 3;

    public bool Tesserato { get; set; } = false;

    [MaxLength(500)]
    public string? Note { get; set; }

    public bool Claimed { get; set; } = false;
    public int? ClaimedByPlayerId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;
}
