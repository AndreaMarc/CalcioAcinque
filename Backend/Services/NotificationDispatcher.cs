using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services.Push;

namespace CalcioAcinque.Backend.Services;

/// <summary>
/// Svuota la coda delle notifiche fuori dal ciclo delle request: convocare 15
/// giocatori vuol dire 15 chiamate HTTP ai push service, che non devono far
/// aspettare l'admin ne' far scadere la request.
/// </summary>
public class NotificationDispatcher : BackgroundService
{
    private const int BatchSize = 50;

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly PushOptions _options;
    private readonly ILogger<NotificationDispatcher> _logger;

    public NotificationDispatcher(
        IServiceScopeFactory scopeFactory,
        IOptions<PushOptions> options,
        ILogger<NotificationDispatcher> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.IsConfigured)
        {
            // Warning e non Information: in produzione il livello e' Warning, e una
            // configurazione mancante che ferma tutte le notifiche non deve essere muta.
            _logger.LogWarning(
                "Notifiche push disattivate: mancano le chiavi VAPID (Push__VapidPublicKey / Push__VapidPrivateKey). " +
                "Generale con: dotnet run --project Backend -- --generate-vapid");
            return;
        }

        var interval = TimeSpan.FromSeconds(Math.Max(5, _options.PollingSeconds));
        _logger.LogInformation("Dispatcher notifiche avviato (polling ogni {Seconds}s)", interval.TotalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var inviate = await ProcessBatchAsync(stoppingToken);
                // Se il batch era pieno c'e' altro da fare: riparte subito invece di aspettare
                if (inviate >= BatchSize) continue;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore nel ciclo del dispatcher notifiche");
            }

            try
            {
                await Task.Delay(interval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task<int> ProcessBatchAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var sender = scope.ServiceProvider.GetRequiredService<IWebPushSender>();

        // Le righe programmate nel futuro restano in coda senza essere toccate:
        // e cosi che funziona il promemoria pre-partita.
        var adesso = DateTime.UtcNow;
        var items = await context.NotificationOutbox
            .Where(n => n.Stato == NotificationStatus.InCoda
                        && (n.ScheduledFor == null || n.ScheduledFor <= adesso))
            .OrderBy(n => n.Id)
            .Take(BatchSize)
            .ToListAsync(ct);

        if (items.Count == 0) return 0;

        var userIds = items.Select(i => i.RecipientUserId).Distinct().ToList();
        var devicesByUser = (await context.PushDevices
                .Where(d => userIds.Contains(d.UserId))
                .ToListAsync(ct))
            .GroupBy(d => d.UserId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var now = DateTime.UtcNow;

        foreach (var item in items)
        {
            if (!devicesByUser.TryGetValue(item.RecipientUserId, out var devices) || devices.Count == 0)
            {
                // Il destinatario ha rimosso tutti i dispositivi dopo l'accodamento
                item.Stato = NotificationStatus.Fallita;
                item.UltimoErrore = "Nessun dispositivo registrato";
                item.Tentativi++;
                continue;
            }

            var consegnataAlmenoUna = false;
            string? ultimoErrore = null;

            foreach (var device in devices.ToList())
            {
                var result = await sender.SendAsync(device, item, ct);

                if (result.Success)
                {
                    consegnataAlmenoUna = true;
                    device.LastUsedAt = now;
                }
                else if (result.DeviceGone)
                {
                    // Subscription morta: tenerla significherebbe fallire per sempre
                    context.PushDevices.Remove(device);
                    devices.Remove(device);
                    ultimoErrore = result.Error;
                }
                else
                {
                    ultimoErrore = result.Error;
                }
            }

            item.Tentativi++;

            if (consegnataAlmenoUna)
            {
                item.Stato = NotificationStatus.Inviata;
                item.SentAt = now;
                item.UltimoErrore = null;
            }
            else
            {
                item.UltimoErrore = ultimoErrore;
                if (item.Tentativi >= _options.MaxTentativi)
                    item.Stato = NotificationStatus.Fallita;
                // altrimenti resta InCoda e ci riprova al giro dopo
            }
        }

        await context.SaveChangesAsync(ct);

        var ok = items.Count(i => i.Stato == NotificationStatus.Inviata);
        var ko = items.Count(i => i.Stato == NotificationStatus.Fallita);
        if (ko > 0)
            _logger.LogWarning("Notifiche: {Ok} inviate, {Ko} fallite definitivamente", ok, ko);

        return items.Count;
    }
}
