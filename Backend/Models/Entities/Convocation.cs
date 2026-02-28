using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("convocations")]
public class Convocation
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int MatchId { get; set; }
    public int PlayerId { get; set; }

    [Required]
    public StatoRisposta StatoRisposta { get; set; } = StatoRisposta.InAttesa;

    public DateTime DataConvocazione { get; set; } = DateTime.UtcNow;
    public DateTime? DataRisposta { get; set; }
    public bool NotificaInviata { get; set; } = false;

    [ForeignKey("MatchId")]
    public virtual Match Match { get; set; } = null!;

    [ForeignKey("PlayerId")]
    public virtual Player Player { get; set; } = null!;
}
