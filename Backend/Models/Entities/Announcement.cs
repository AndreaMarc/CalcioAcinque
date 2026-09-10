using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("announcements")]
public class Announcement
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamId { get; set; }

    /// <summary>
    /// Nullable per lo stesso motivo di TokenTransaction.AdminId: chi ha scritto
    /// puo' uscire dalla rosa, la comunicazione resta con il nome congelato.
    /// </summary>
    public int? AuthorId { get; set; }

    [Required, MaxLength(100)]
    public string AutoreNome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? AutoreSoprannome { get; set; }

    [Required, MaxLength(200)]
    public string Titolo { get; set; } = string.Empty;

    [Required, MaxLength(2000)]
    public string Contenuto { get; set; } = string.Empty;

    public bool Importante { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("AuthorId")]
    public virtual Player? Author { get; set; }

    public virtual ICollection<AnnouncementRead> Reads { get; set; } = new List<AnnouncementRead>();
}
