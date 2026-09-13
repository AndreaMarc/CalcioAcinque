using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Voto per il migliore in campo di una partita: un voto per votante, modificabile.
/// </summary>
[Table("match_votes")]
public class MatchVote
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int MatchId { get; set; }

    /// <summary>Chi vota.</summary>
    [Required]
    public int VoterPlayerId { get; set; }

    /// <summary>Chi riceve il voto.</summary>
    [Required]
    public int VotedPlayerId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("MatchId")]
    public virtual Match Match { get; set; } = null!;

    [ForeignKey("VoterPlayerId")]
    public virtual Player Voter { get; set; } = null!;

    [ForeignKey("VotedPlayerId")]
    public virtual Player Voted { get; set; } = null!;
}
