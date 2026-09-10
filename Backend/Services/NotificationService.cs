using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Notifications;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services.Push;

namespace CalcioAcinque.Backend.Services;

public interface INotificationService
{
    Task<PushConfigDto> GetConfigAsync(int userId);
    Task RegisterDeviceAsync(int userId, RegisterPushDeviceDto dto);
    Task UnregisterDeviceAsync(int userId, string endpoint);
    Task UpdatePreferenceAsync(int userId, UpdateNotificationPreferenceDto dto);
    Task<int> SendTestAsync(int userId);

    /// <summary>
    /// Mette in coda una notifica per ogni destinatario che la vuole e ha almeno
    /// un dispositivo. Non spedisce nulla: ci pensa <see cref="NotificationDispatcher"/>.
    /// Ritorna quante ne ha accodate.
    /// </summary>
    Task<int> QueueAsync(
        NotificationKind kind,
        IEnumerable<int> recipientUserIds,
        string titolo,
        string corpo,
        string? url = null,
        string? tag = null,
        int? teamId = null,
        DateTime? scheduledFor = null,
        CancellationToken ct = default);
}

public class NotificationService : INotificationService
{
    private readonly ApplicationDbContext _context;
    private readonly PushOptions _options;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        ApplicationDbContext context,
        IOptions<PushOptions> options,
        ILogger<NotificationService> logger)
    {
        _context = context;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<PushConfigDto> GetConfigAsync(int userId)
    {
        var preferenze = await _context.NotificationPreferences
            .Where(p => p.UserId == userId)
            .ToDictionaryAsync(p => p.Kind, p => p.Enabled);

        return new PushConfigDto
        {
            Enabled = _options.IsConfigured,
            PublicKey = _options.IsConfigured ? _options.VapidPublicKey : null,
            DispositiviRegistrati = await _context.PushDevices.CountAsync(d => d.UserId == userId),
            Tipi = NotificationKinds.Configurabili.Select(k => new NotificationKindDto
            {
                Valore = k.ToString(),
                Label = NotificationKinds.Label(k),
                Descrizione = NotificationKinds.Descrizione(k),
                // Assente in tabella = attiva
                Attiva = !preferenze.TryGetValue(k, out var enabled) || enabled
            }).ToList()
        };
    }

    public async Task RegisterDeviceAsync(int userId, RegisterPushDeviceDto dto)
    {
        if (!_options.IsConfigured)
            throw new BusinessException("Le notifiche non sono configurate sul server");

        // L'endpoint identifica il browser: reinstallando la PWA ne arriva uno nuovo,
        // quindi la stessa persona puo' avere piu' righe (una per dispositivo).
        var existing = await _context.PushDevices.FirstOrDefaultAsync(d => d.Endpoint == dto.Endpoint);

        if (existing != null)
        {
            existing.UserId = userId;
            existing.P256dh = dto.P256dh;
            existing.Auth = dto.Auth;
            existing.Descrizione = dto.Descrizione;
            existing.LastUsedAt = DateTime.UtcNow;
        }
        else
        {
            _context.PushDevices.Add(new PushDevice
            {
                UserId = userId,
                Endpoint = dto.Endpoint,
                P256dh = dto.P256dh,
                Auth = dto.Auth,
                Descrizione = dto.Descrizione,
                CreatedAt = DateTime.UtcNow,
                LastUsedAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Dispositivo push registrato per utente {UserId}", userId);
    }

    public async Task UnregisterDeviceAsync(int userId, string endpoint)
    {
        var device = await _context.PushDevices
            .FirstOrDefaultAsync(d => d.Endpoint == endpoint && d.UserId == userId);
        if (device == null) return;

        _context.PushDevices.Remove(device);
        await _context.SaveChangesAsync();
    }

    public async Task UpdatePreferenceAsync(int userId, UpdateNotificationPreferenceDto dto)
    {
        if (!Enum.TryParse<NotificationKind>(dto.Kind, true, out var kind)
            || !NotificationKinds.Configurabili.Contains(kind))
            throw new BadRequestException($"Tipo di notifica non valido: {dto.Kind}");

        var pref = await _context.NotificationPreferences
            .FirstOrDefaultAsync(p => p.UserId == userId && p.Kind == kind);

        if (pref == null)
        {
            pref = new NotificationPreference { UserId = userId, Kind = kind, Enabled = dto.Enabled };
            _context.NotificationPreferences.Add(pref);
        }
        else
        {
            pref.Enabled = dto.Enabled;
        }

        await _context.SaveChangesAsync();
    }

    public async Task<int> SendTestAsync(int userId)
    {
        if (!_options.IsConfigured)
            throw new BusinessException("Le notifiche non sono configurate sul server");

        var dispositivi = await _context.PushDevices.CountAsync(d => d.UserId == userId);
        if (dispositivi == 0)
            throw new BusinessException(
                "Nessun dispositivo registrato: attiva prima le notifiche su questo telefono");

        _context.NotificationOutbox.Add(new NotificationOutboxItem
        {
            RecipientUserId = userId,
            Kind = NotificationKind.Prova,
            Titolo = "Notifica di prova",
            Corpo = "Se leggi questo messaggio le notifiche funzionano.",
            Url = "/dashboard",
            Tag = "prova",
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();
        return dispositivi;
    }

    public async Task<int> QueueAsync(
        NotificationKind kind,
        IEnumerable<int> recipientUserIds,
        string titolo,
        string corpo,
        string? url = null,
        string? tag = null,
        int? teamId = null,
        DateTime? scheduledFor = null,
        CancellationToken ct = default)
    {
        if (!_options.IsConfigured) return 0;

        var userIds = recipientUserIds.Distinct().ToList();
        if (userIds.Count == 0) return 0;

        // Solo chi ha almeno un dispositivo: accodare per gli altri riempirebbe la tabella di righe morte
        var conDispositivo = await _context.PushDevices
            .Where(d => userIds.Contains(d.UserId))
            .Select(d => d.UserId)
            .Distinct()
            .ToListAsync(ct);
        if (conDispositivo.Count == 0) return 0;

        var disattivata = await _context.NotificationPreferences
            .Where(p => conDispositivo.Contains(p.UserId) && p.Kind == kind && !p.Enabled)
            .Select(p => p.UserId)
            .ToListAsync(ct);

        var destinatari = conDispositivo.Except(disattivata).ToList();
        if (destinatari.Count == 0) return 0;

        _context.NotificationOutbox.AddRange(destinatari.Select(userId => new NotificationOutboxItem
        {
            RecipientUserId = userId,
            TeamId = teamId,
            Kind = kind,
            Titolo = Tronca(titolo, 150),
            Corpo = Tronca(corpo, 500),
            Url = url,
            Tag = tag,
            ScheduledFor = scheduledFor,
            CreatedAt = DateTime.UtcNow
        }));

        await _context.SaveChangesAsync(ct);
        return destinatari.Count;
    }

    private static string Tronca(string value, int max) =>
        value.Length <= max ? value : value[..(max - 1)] + "…";
}
