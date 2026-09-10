using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("matches")]
public class Match
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamId { get; set; }

    /// <summary>Stagione a cui appartiene. Null solo per dati anteriori alle stagioni.</summary>
    public int? SeasonId { get; set; }

    public DateTime Data { get; set; }
    public TimeSpan Ora { get; set; }

    [MaxLength(255)]
    public string? Luogo { get; set; }

    [MaxLength(255)]
    public string? Titolo { get; set; }

    public int NumeroGiornata { get; set; }

    [Required]
    public StatoPartita Stato { get; set; } = StatoPartita.Programmata;

    [MaxLength(500)]
    public string? Note { get; set; }

    /// <summary>
    /// Quando il promemoria e stato accodato. Serve a non mandarlo due volte;
    /// spostando la partita viene azzerato, cosi ne parte uno nuovo.
    /// </summary>
    public DateTime? PromemoriaInviatoAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("SeasonId")]
    public virtual Season? Season { get; set; }

    public virtual ICollection<Convocation> Convocations { get; set; } = new List<Convocation>();
    public virtual ICollection<MatchAttendance> Attendances { get; set; } = new List<MatchAttendance>();
    public virtual ICollection<TokenTransaction> TokenTransactions { get; set; } = new List<TokenTransaction>();
    public virtual ICollection<PlayerAvailability> Availabilities { get; set; } = new List<PlayerAvailability>();
}
