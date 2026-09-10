using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Preferenza per tipo di notifica. Assente = attiva: chi non ha mai toccato le
/// impostazioni riceve tutto, e in tabella finiscono solo le scelte esplicite.
/// </summary>
[Table("notification_preferences")]
public class NotificationPreference
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int UserId { get; set; }

    [Required]
    public NotificationKind Kind { get; set; }

    public bool Enabled { get; set; } = true;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;
}
