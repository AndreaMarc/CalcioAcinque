using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

/// <summary>
/// Una subscription push del browser. E' legata all'utente e non al giocatore:
/// la persona e' una sola anche se gioca in due squadre della societa'.
/// C'e' una riga per ogni browser/dispositivo, non per utente.
/// </summary>
[Table("push_devices")]
public class PushDevice
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int UserId { get; set; }

    /// <summary>URL del push service (Apple, Google, Mozilla...). Identifica il dispositivo.</summary>
    [Required, MaxLength(500)]
    public string Endpoint { get; set; } = string.Empty;

    /// <summary>Chiave pubblica P-256 del browser, base64url.</summary>
    [Required, MaxLength(255)]
    public string P256dh { get; set; } = string.Empty;

    /// <summary>Segreto di autenticazione del browser, base64url.</summary>
    [Required, MaxLength(255)]
    public string Auth { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Descrizione { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastUsedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;
}
