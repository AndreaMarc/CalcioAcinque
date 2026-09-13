using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Un compito di squadra che gira a turno tra i convocati: chi porta le casacche,
/// chi lava le maglie, chi prende i palloni.
/// </summary>
[Table("team_chores")]
public class TeamChore
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TeamId { get; set; }

    [Required, MaxLength(60)]
    public string Nome { get; set; } = string.Empty;

    public bool Attivo { get; set; } = true;

    public int Ordine { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    public virtual ICollection<MatchChoreAssignment> Assignments { get; set; } = new List<MatchChoreAssignment>();
}

/// <summary>A chi tocca un compito in una certa partita.</summary>
[Table("match_chore_assignments")]
public class MatchChoreAssignment
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int MatchId { get; set; }

    [Required]
    public int ChoreId { get; set; }

    /// <summary>Null = ancora da assegnare.</summary>
    public int? PlayerId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("MatchId")]
    public virtual Match Match { get; set; } = null!;

    [ForeignKey("ChoreId")]
    public virtual TeamChore Chore { get; set; } = null!;

    [ForeignKey("PlayerId")]
    public virtual Player? Player { get; set; }
}
