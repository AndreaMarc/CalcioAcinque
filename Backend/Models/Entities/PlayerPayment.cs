using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("player_payments")]
public class PlayerPayment
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    /// <summary>
    /// Squadra a cui appartiene la voce. Ridondante rispetto a Player.TeamId, ma
    /// necessaria: se il giocatore viene cancellato PlayerId diventa null e senza
    /// questa colonna la voce spirirebbe dagli elenchi della squadra.
    /// </summary>
    public int TeamId { get; set; }

    /// <summary>
    /// Null se il giocatore e stato cancellato: la voce resta come traccia
    /// contabile invece di sparire in cascata.
    /// </summary>
    public int? PlayerId { get; set; }

    /// <summary>Nome congelato alla creazione: sopravvive alla cancellazione del giocatore.</summary>
    [Required, MaxLength(100)]
    public string NomeGiocatore { get; set; } = string.Empty;

    /// <summary>
    /// Partita che ha generato l addebito, null per le quote fisse. La FK e
    /// SetNull: se la partita viene cancellata la voce di pagamento resta, per
    /// questo la Descrizione va scritta autoesplicativa alla creazione.
    /// </summary>
    public int? MatchId { get; set; }

    /// <summary>Stagione di competenza: chiuderla archivia anche i conti.</summary>
    public int? SeasonId { get; set; }

    [Required, MaxLength(255)]
    public string Descrizione { get; set; } = string.Empty;

    [Column(TypeName = "decimal(10,2)")]
    public decimal Importo { get; set; }

    [Required]
    public TipoPagamento Tipo { get; set; } = TipoPagamento.Altro;

    public DateTime DataPagamento { get; set; }

    /// <summary>Confermato dall admin: e questo che fa fede.</summary>
    public bool Pagato { get; set; } = false;

    /// <summary>
    /// Quando il giocatore ha dichiarato di aver pagato. Non-null significa
    /// in verifica: la conferma resta comunque all admin via <see cref="Pagato"/>.
    /// </summary>
    public DateTime? DichiaratoPagatoAt { get; set; }

    /// <summary>Chi ha registrato la voce. Null se quel giocatore non c e piu.</summary>
    public int? AdminId { get; set; }

    /// <summary>Nome congelato di chi ha registrato la voce.</summary>
    [MaxLength(100)]
    public string? AdminNome { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamId")]
    public virtual Team Team { get; set; } = null!;

    [ForeignKey("PlayerId")]
    public virtual Player? Player { get; set; }

    [ForeignKey("MatchId")]
    public virtual Match? Match { get; set; }

    [ForeignKey("SeasonId")]
    public virtual Season? Season { get; set; }

    [ForeignKey("AdminId")]
    public virtual Player? Admin { get; set; }
}
