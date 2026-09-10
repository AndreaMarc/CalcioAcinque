using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class JoinTeamRequest
{
    /// <summary>Codice di una squadra oppure di una societa'.</summary>
    [Required]
    public string InviteCode { get; set; } = string.Empty;

    /// <summary>
    /// Squadra scelta. Obbligatorio quando <see cref="InviteCode"/> e' il codice di una societa'
    /// con piu' di una squadra; ignorato per i codici di squadra.
    /// </summary>
    public int? TeamId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }

    /// <summary>Opzionale: id del PendingPlayer che il nuovo utente "rivendica" come sé stesso.</summary>
    public int? PendingPlayerId { get; set; }
}
