using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("match_attendance")]
public class MatchAttendance
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int MatchId { get; set; }
    public int PlayerId { get; set; }

    public bool Convocato { get; set; } = false;
    public bool Presente { get; set; } = false;
    public bool HaGiocato { get; set; } = false;
    public bool GettoneConsumato { get; set; } = false;

    // Statistiche facoltative
    public int? MinutiGiocati { get; set; }
    public int? Goal { get; set; }
    public int? Assist { get; set; }
    public int? Autogoal { get; set; }
    public int? Ammonizioni { get; set; }
    public int? Espulsioni { get; set; }
    public int? GoalSubiti { get; set; }

    [ForeignKey("MatchId")]
    public virtual Match Match { get; set; } = null!;

    [ForeignKey("PlayerId")]
    public virtual Player Player { get; set; } = null!;
}
