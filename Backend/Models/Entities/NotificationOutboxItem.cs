using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Notifica in attesa di essere spedita. Passa da una tabella e non da una coda
/// in memoria per due motivi: convocare 15 giocatori non deve allungare la request
/// HTTP, e un invio fallito deve restare visibile (Tentativi, UltimoErrore).
/// </summary>
[Table("notification_outbox")]
public class NotificationOutboxItem
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int RecipientUserId { get; set; }

    /// <summary>Squadra di contesto: con due squadre nella stessa societa' serve a dire quale.</summary>
    public int? TeamId { get; set; }

    [Required]
    public NotificationKind Kind { get; set; }

    [Required, MaxLength(150)]
    public string Titolo { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Corpo { get; set; } = string.Empty;

    /// <summary>Rotta dell'app da aprire al tap (es. "/match/12").</summary>
    [MaxLength(255)]
    public string? Url { get; set; }

    /// <summary>Tag del browser: due notifiche con lo stesso tag si sostituiscono invece di accumularsi.</summary>
    [MaxLength(100)]
    public string? Tag { get; set; }

    [Required]
    public NotificationStatus Stato { get; set; } = NotificationStatus.InCoda;

    /// <summary>
    /// Non spedire prima di questo momento. Null = subito. Serve al promemoria
    /// pre-partita, che si accoda quando la partita viene creata o spostata.
    /// </summary>
    public DateTime? ScheduledFor { get; set; }

    public int Tentativi { get; set; }

    [MaxLength(500)]
    public string? UltimoErrore { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? SentAt { get; set; }

    [ForeignKey("RecipientUserId")]
    public virtual User Recipient { get; set; } = null!;
}
