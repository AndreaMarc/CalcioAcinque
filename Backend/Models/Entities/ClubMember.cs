using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Anagrafica unica di societa'. Una persona esiste una volta sola nella societa'
/// e ha un <see cref="Player"/> ("tessera") per ogni squadra in cui gioca.
/// Nome/Soprannome/Telefono sono replicati sui Player per non riscrivere tutte le query:
/// la sorgente di verita' e' questa entita', la propagazione avviene in ClubService/PlayerService.
/// </summary>
[Table("club_members")]
public class ClubMember
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int ClubId { get; set; }

    /// <summary>Null finche' la persona non ha un account (anagrafica creata dall'admin).</summary>
    public int? UserId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }

    public DateTime? DataNascita { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("ClubId")]
    public virtual Club Club { get; set; } = null!;

    [ForeignKey("UserId")]
    public virtual User? User { get; set; }

    public virtual ICollection<Player> Players { get; set; } = new List<Player>();
}
