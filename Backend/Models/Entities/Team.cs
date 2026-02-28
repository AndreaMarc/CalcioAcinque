using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("teams")]
public class Team
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [MaxLength(20)]
    public string? InviteCode { get; set; }

    public virtual ICollection<Player> Players { get; set; } = new List<Player>();
    public virtual ICollection<Match> Matches { get; set; } = new List<Match>();
}
