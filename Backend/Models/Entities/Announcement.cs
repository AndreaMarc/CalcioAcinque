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
    public int AuthorId { get; set; }

    [Required, MaxLength(200)]
    public string Titolo { get; set; } = string.Empty;

    [Required, MaxLength(2000)]
    public string Contenuto { get; set; } = string.Empty;

    public bool Importante { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("AuthorId")]
    public virtual Player Author { get; set; } = null!;

    public virtual ICollection<AnnouncementRead> Reads { get; set; } = new List<AnnouncementRead>();
}
