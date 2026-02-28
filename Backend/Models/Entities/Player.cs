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

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }

    [Required]
    public UserRole Ruolo { get; set; } = UserRole.User;

    public int GettoniTotali { get; set; }
    public int GettoniConsumati { get; set; } = 0;

    public bool IscrizionePagata { get; set; } = false;
    public bool TesseramentoPagato { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [NotMapped]
    public int GettoniRimanenti => GettoniTotali - GettoniConsumati;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    public virtual ICollection<Convocation> Convocations { get; set; } = new List<Convocation>();
    public virtual ICollection<MatchAttendance> Attendances { get; set; } = new List<MatchAttendance>();
    public virtual ICollection<TokenTransaction> TokenTransactions { get; set; } = new List<TokenTransaction>();
    public virtual ICollection<PlayerPayment> Payments { get; set; } = new List<PlayerPayment>();
    public virtual ICollection<PlayerAvailability> Availabilities { get; set; } = new List<PlayerAvailability>();
}
