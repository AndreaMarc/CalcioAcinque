using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services.Push;

namespace CalcioAcinque.Backend.Services;

/// <summary>
/// Il lunedi' mattina ricorda a chi tiene la cassa cosa manca: arretrati e
/// partite concluse senza incasso. Una notifica per squadra per settimana;
/// l'idempotenza sta sul tag nella outbox, cosi' un riavvio non la rimanda.
/// </summary>
public class CassaDigestService : BackgroundService
{
    private static readonly TimeSpan Intervallo = TimeSpan.FromMinutes(30);
    private const int OraInvio = 9; // ora italiana

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly PushOptions _options;
    private readonly ILogger<CassaDigestService> _logger;

    public CassaDigestService(
        IServiceScopeFactory scopeFactory,
        IOptions<PushOptions> options,
        ILogger<CassaDigestService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.IsConfigured)
        {
            _logger.LogWarning("Riepilogo cassa disattivato: mancano le chiavi VAPID");
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var adesso = AppTime.ToLocal(DateTime.UtcNow);
                if (adesso.DayOfWeek == DayOfWeek.Monday && adesso.Hour == OraInvio)
                    await ProcessAsync(adesso, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore nel riepilogo cassa settimanale");
            }

            try { await Task.Delay(Intervallo, stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task ProcessAsync(DateTime adessoLocale, CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var expenses = scope.ServiceProvider.GetRequiredService<IExpenseService>();
        var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var settimana = $"{ISOWeek.GetYear(adessoLocale)}-W{ISOWeek.GetWeekOfYear(adessoLocale):00}";
        var teams = await context.Teams.Select(t => new { t.Id, t.Nome }).ToListAsync(ct);

        foreach (var team in teams)
        {
            var tag = $"cassa-{team.Id}-{settimana}";
            if (await context.NotificationOutbox.AnyAsync(n => n.Tag == tag, ct)) continue;

            var cassa = await expenses.GetCassaAsync(team.Id, null);
            var arretrati = cassa.Arretrati.Sum(a => a.Importo);
            var daIncassare = cassa.PartiteNonIncassate.Count(p => p.PresentiAPartita > 0);
            if (arretrati <= 0 && daIncassare == 0) continue;

            var destinatari = await context.Players
                .Where(p => p.TeamId == team.Id && (p.Ruolo == UserRole.Admin || p.Ruolo == UserRole.Cassiere))
                .Select(p => p.UserId)
                .ToListAsync(ct);
            if (destinatari.Count == 0) continue;

            var pezzi = new List<string>();
            if (arretrati > 0)
                pezzi.Add($"{PaymentService.Euro(arretrati)} da incassare da {cassa.Arretrati.Count} giocatori");
            if (daIncassare > 0)
                pezzi.Add($"{daIncassare} partit{(daIncassare == 1 ? "a" : "e")} senza incasso");

            var accodate = await notifications.QueueAsync(
                NotificationKind.RiepilogoCassa,
                destinatari,
                titolo: $"{team.Nome}: la cassa della settimana",
                corpo: string.Join(" · ", pezzi) + ". Apri la cassa per sistemare.",
                url: "/payments",
                tag: tag,
                teamId: team.Id,
                ct: ct);

            if (accodate > 0)
                _logger.LogInformation("Riepilogo cassa {Team}: {N} notifiche", team.Nome, accodate);
        }
    }
}
