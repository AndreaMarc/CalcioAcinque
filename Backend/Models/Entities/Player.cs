using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("players")]
public class Player
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamId { get; set; }
    public int UserId { get; set; }

    /// <summary>Anagrafica di societa' a cui questa tessera appartiene. Null solo per dati pre-societa'.</summary>
    public int? ClubMemberId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }

    [Required]
    public UserRole Ruolo { get; set; } = UserRole.User;

    /// <summary>Ruolo in campo in QUESTA squadra: lo stesso giocatore puo' avere ruoli diversi a 5 e a 7.</summary>
    public PlayerPosition? Posizione { get; set; }

    public int? NumeroMaglia { get; set; }

    /// <summary>Falso per chi e' solo staff (allenatore, dirigente): non entra in rosa,
    /// convocazioni e statistiche, ma dichiara la presenza alla partita come gli altri.</summary>
    public bool Gioca { get; set; } = true;

    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; } = 0;

    /// <summary>
    /// Regime di pagamento personale. Null significa deliberatamente
    /// eredita il default della squadra: cosi cambiare il default vale
    /// per tutti quelli che non hanno una scelta esplicita.
    /// </summary>
    public RegimePagamento? RegimePagamento { get; set; }

    public bool IscrizionePagata { get; set; } = false;
    public bool TesseramentoPagato { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [NotMapped]
    public int GettoniRimanenti => GettoniTotali - GettoniConsumati;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    [ForeignKey("ClubMemberId")]
    public virtual ClubMember? ClubMember { get; set; }

    public virtual ICollection<Convocation> Convocations { get; set; } = new List<Convocation>();
    public virtual ICollection<MatchAttendance> Attendances { get; set; } = new List<MatchAttendance>();
    public virtual ICollection<TokenTransaction> TokenTransactions { get; set; } = new List<TokenTransaction>();
    public virtual ICollection<PlayerPayment> Payments { get; set; } = new List<PlayerPayment>();
    public virtual ICollection<PlayerAvailability> Availabilities { get; set; } = new List<PlayerAvailability>();
}
