using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("draft_candidates")]
public class DraftCandidate
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamDraftId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    public PlayerPosition? Posizione { get; set; }

    [Required]
    public DraftStatus Stato { get; set; } = DraftStatus.DaSentire;

    [Range(1, 5)]
    public int Bravura { get; set; } = 3;

    [Range(1, 5)]
    public int Affidabilita { get; set; } = 3;

    public bool Tesserato { get; set; } = false;

    public bool IsFriend { get; set; } = false;

    [MaxLength(500)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamDraftId")]
    public virtual TeamDraft TeamDraft { get; set; } = null!;
}
