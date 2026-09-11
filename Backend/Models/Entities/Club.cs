using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Societa' sportiva: contenitore di piu' squadre (es. una a 5 e una a 7) che
/// condividono l'anagrafica dei giocatori ma hanno regole e costi propri.
/// </summary>
[Table("clubs")]
public class Club
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    /// <summary>Codice invito a livello societa': chi lo usa entra nell'anagrafica e sceglie la squadra.</summary>
    [MaxLength(20)]
    public string? InviteCode { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Chi ha creato la societa': finche' non ha giocatori e' l'unico che puo'
    /// gestirla (prima bastava esserne membro).
    /// </summary>
    public int? CreatedByUserId { get; set; }

    // --- Dati per pagare, validi per tutte le squadre salvo override sulla singola ---

    /// <summary>Link PayPal.me o simile, aperto in una nuova scheda dal client.</summary>
    [MaxLength(255)]
    public string? PaypalLink { get; set; }

    [MaxLength(34)]
    public string? Iban { get; set; }

    [MaxLength(100)]
    public string? IntestatarioIban { get; set; }

    public virtual ICollection<Team> Teams { get; set; } = new List<Team>();
    public virtual ICollection<ClubMember> Members { get; set; } = new List<ClubMember>();
}
