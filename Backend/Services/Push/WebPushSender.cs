using System.Net;
using System.Text.Json;
using Lib.Net.Http.WebPush;
using Lib.Net.Http.WebPush.Authentication;
using Microsoft.Extensions.Options;
using CalcioAcinque.Backend.Models.Entities;
using LibPushSubscription = Lib.Net.Http.WebPush.PushSubscription;

namespace CalcioAcinque.Backend.Services.Push;

/// <summary>
/// Esito di un invio. <paramref name="DeviceGone"/> distingue il caso in cui la
/// subscription non esiste piu' (browser disinstallato, permesso revocato): li'
/// non ha senso ritentare, la riga va cancellata.
/// </summary>
public record PushSendResult(bool Success, bool DeviceGone, string? Error)
{
    public static PushSendResult Ok() => new(true, false, null);
    public static PushSendResult Gone(string error) => new(false, true, error);
    public static PushSendResult Failed(string error) => new(false, false, error);
}

public interface IWebPushSender
{
    bool IsConfigured { get; }
    Task<PushSendResult> SendAsync(PushDevice device, NotificationOutboxItem item, CancellationToken ct);
}

public class WebPushSender : IWebPushSender
{
    private readonly PushServiceClient _client;
    private readonly PushOptions _options;
    private readonly ILogger<WebPushSender> _logger;

    public WebPushSender(
        PushServiceClient client,
        IOptions<PushOptions> options,
        ILogger<WebPushSender> logger)
    {
        _client = client;
        _options = options.Value;
        _logger = logger;

        if (_options.IsConfigured)
        {
            _client.DefaultAuthentication = new VapidAuthentication(
                _options.VapidPublicKey!, _options.VapidPrivateKey!)
            {
                Subject = _options.Subject
            };
        }
    }

    public bool IsConfigured => _options.IsConfigured;

    public async Task<PushSendResult> SendAsync(
        PushDevice device, NotificationOutboxItem item, CancellationToken ct)
    {
        if (!IsConfigured)
            return PushSendResult.Failed("Chiavi VAPID non configurate");

        var subscription = new LibPushSubscription { Endpoint = device.Endpoint };
        subscription.SetKey(PushEncryptionKeyName.P256DH, device.P256dh);
        subscription.SetKey(PushEncryptionKeyName.Auth, device.Auth);

        // Il payload viaggia cifrato fino al browser: lo legge solo il service worker
        var payload = JsonSerializer.Serialize(new
        {
            title = item.Titolo,
            body = item.Corpo,
            url = item.Url,
            tag = item.Tag,
            kind = item.Kind.ToString()
        });

        var message = new PushMessage(payload)
        {
            Topic = item.Tag,
            Urgency = item.Kind == Models.Enums.NotificationKind.Convocazione
                ? PushMessageUrgency.High
                : PushMessageUrgency.Normal
        };

        try
        {
            await _client.RequestPushMessageDeliveryAsync(subscription, message, ct);
            return PushSendResult.Ok();
        }
        catch (PushServiceClientException ex)
        {
            // 404/410 = subscription non piu' valida; 403 = VAPID rifiutata (chiave sbagliata)
            if (ex.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.Gone)
                return PushSendResult.Gone($"{(int)ex.StatusCode} {ex.StatusCode}");

            _logger.LogWarning(
                "Push rifiutata dal servizio: {Status} {Body}", ex.StatusCode, Troncato(ex.Body));
            return PushSendResult.Failed($"{(int)ex.StatusCode} {Troncato(ex.Body)}");
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning(ex, "Errore di rete nell'invio push");
            return PushSendResult.Failed(Troncato(ex.Message));
        }
    }

    private static string Troncato(string? value) =>
        string.IsNullOrEmpty(value) ? string.Empty
            : value.Length <= 200 ? value : value[..200];
}
