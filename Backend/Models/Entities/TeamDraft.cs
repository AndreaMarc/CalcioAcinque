using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("team_drafts")]
public class TeamDraft
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int UserId { get; set; }

    [Required, MaxLength(100)]
    public string NomeTeam { get; set; } = string.Empty;

    /// <summary>Disciplina pianificata: decide i ruoli proponibili e le regole della squadra creata.</summary>
    public TeamFormat Formato { get; set; } = TeamFormat.CalcioA5;

    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [MaxLength(20)]
    public string? ShareCode { get; set; }

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    public virtual ICollection<DraftCandidate> Candidates { get; set; } = new List<DraftCandidate>();
    public virtual ICollection<DraftCollaborator> Collaborators { get; set; } = new List<DraftCollaborator>();
}
