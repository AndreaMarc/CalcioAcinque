using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Notifications;

/// <summary>Quello che serve al client per decidere se e come proporre le notifiche.</summary>
public class PushConfigDto
{
    /// <summary>False se il server non ha le chiavi VAPID: il client non deve nemmeno chiedere il permesso.</summary>
    public bool Enabled { get; set; }

    /// <summary>Chiave pubblica VAPID in base64url, da passare a pushManager.subscribe.</summary>
    public string? PublicKey { get; set; }

    public List<NotificationKindDto> Tipi { get; set; } = new();

    /// <summary>Dispositivi gia' registrati per questo utente.</summary>
    public int DispositiviRegistrati { get; set; }
}

public class NotificationKindDto
{
    public string Valore { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public string Descrizione { get; set; } = string.Empty;
    public bool Attiva { get; set; } = true;
}

public class RegisterPushDeviceDto
{
    [Required, MaxLength(500)]
    public string Endpoint { get; set; } = string.Empty;

    [Required, MaxLength(255)]
    public string P256dh { get; set; } = string.Empty;

    [Required, MaxLength(255)]
    public string Auth { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Descrizione { get; set; }
}

public class UnregisterPushDeviceDto
{
    [Required, MaxLength(500)]
    public string Endpoint { get; set; } = string.Empty;
}

public class UpdateNotificationPreferenceDto
{
    /// <summary>Convocazione | Avviso | PartitaAggiornata</summary>
    [Required]
    public string Kind { get; set; } = string.Empty;

    public bool Enabled { get; set; } = true;
}
