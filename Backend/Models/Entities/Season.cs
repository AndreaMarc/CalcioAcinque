using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Stagione sportiva di UNA squadra: l'a5 e l'a7 possono avere campionati con
/// inizio e fine diversi, quindi si aprono e si chiudono separatamente.
///
/// Partite e pagamenti sono legati alla stagione: chiuderla li rende storia
/// consultabile e riporta a zero i contatori dei giocatori.
/// </summary>
[Table("seasons")]
public class Season
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamId { get; set; }

    /// <summary>Etichetta leggibile, tipicamente "2026/27".</summary>
    [Required, MaxLength(50)]
    public string Nome { get; set; } = string.Empty;

    public DateTime DataInizio { get; set; } = DateTime.UtcNow;

    /// <summary>Valorizzata alla chiusura.</summary>
    public DateTime? DataFine { get; set; }

    /// <summary>
    /// Una chiusa e' in sola lettura. Per ogni squadra ce n'e' al massimo una
    /// aperta: il vincolo e' applicato in <c>SeasonService</c>.
    /// </summary>
    public bool Chiusa { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    public virtual ICollection<Match> Matches { get; set; } = new List<Match>();
}
