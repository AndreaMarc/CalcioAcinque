using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("announcement_reads")]
public class AnnouncementRead
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int AnnouncementId { get; set; }
    public int PlayerId { get; set; }

    public DateTime ReadAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("AnnouncementId")]
    public virtual Announcement Announcement { get; set; } = null!;

    [ForeignKey("PlayerId")]
    public virtual Player Player { get; set; } = null!;
}
