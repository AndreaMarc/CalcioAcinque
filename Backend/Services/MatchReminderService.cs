using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services.Push;

namespace CalcioAcinque.Backend.Services;

/// <summary>
/// Accoda il promemoria pre-partita ai convocati, N ore prima del fischio
/// d'inizio (<c>Team.OrePromemoriaPartita</c>, 0 = spento).
///
/// Guarda un po' avanti e usa <c>ScheduledFor</c> per far consegnare al minuto
/// giusto dal dispatcher: cosi' questo job puo' girare ogni 10 minuti e lo
/// stato delle risposte viene letto poco prima dell'invio, quindi il testo
/// distingue chi ha confermato da chi non ha ancora risposto.
///
/// L'idempotenza sta su <c>Match.PromemoriaInviatoAt</c>: spostare la partita
/// lo azzera (vedi <c>MatchService.UpdateAsync</c>) e ne fa partire uno nuovo.
/// </summary>
public class MatchReminderService : BackgroundService
{
    private static readonly TimeSpan Intervallo = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan Lookahead = TimeSpan.FromMinutes(15);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly PushOptions _options;
    private readonly ILogger<MatchReminderService> _logger;

    public MatchReminderService(
        IServiceScopeFactory scopeFactory,
        IOptions<PushOptions> options,
        ILogger<MatchReminderService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.IsConfigured)
        {
            _logger.LogWarning("Promemoria partita disattivati: mancano le chiavi VAPID");
            return;
        }

        _logger.LogInformation(
            "Promemoria partita attivi (controllo ogni {Minuti} minuti)", Intervallo.TotalMinutes);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Errore nel ciclo dei promemoria partita");
            }

            try
            {
                await Task.Delay(Intervallo, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }
    }

    private async Task ProcessAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var adesso = DateTime.UtcNow;
        var limite = adesso.Add(Lookahead);

        // Solo partite future non ancora concluse, con convocazioni inviate e
        // promemoria mai accodato. Il filtro fine sull'orario si fa in memoria:
        // Data e Ora sono due colonne separate e comporle in SQL e' fragile.
        var candidate = await context.Matches
            .Include(m => m.Team)
            .Where(m => m.PromemoriaInviatoAt == null
                        && m.Stato != StatoPartita.Conclusa
                        && m.Data >= adesso.Date.AddDays(-1)
                        && m.Team.OrePromemoriaPartita > 0)
            .ToListAsync(ct);

        if (candidate.Count == 0) return;

        var accodatiTotali = 0;

        foreach (var match in candidate)
        {
            var inizio = match.Data.Date.Add(match.Ora);
            var promemoria = inizio.AddHours(-match.Team.OrePromemoriaPartita);

            // Non ancora nella finestra: se ne riparla al giro successivo
            if (promemoria > limite) continue;
            // Ormai la partita e' iniziata: mandarlo adesso non serve a nulla
            if (inizio <= adesso) continue;

            var convocazioni = await context.Convocations
                .Include(c => c.Player)
                .Where(c => c.MatchId == match.Id)
                .ToListAsync(ct);

            if (convocazioni.Count == 0) continue;

            var quando = inizio.ToString("dd/MM 'alle' HH:mm");
            var dove = string.IsNullOrWhiteSpace(match.Luogo) ? string.Empty : $" - {match.Luogo}";
            var avversario = string.IsNullOrWhiteSpace(match.Titolo)
                ? $"Giornata {match.NumeroGiornata}"
                : $"vs {match.Titolo}";

            // Due messaggi diversi: a chi non ha risposto serve un sollecito,
            // a chi ha confermato basta il promemoria.
            var daSollecitare = convocazioni
                .Where(c => c.StatoRisposta == StatoRisposta.InAttesa)
                .Select(c => c.Player.UserId)
                .ToList();

            var daRicordare = convocazioni
                .Where(c => c.StatoRisposta == StatoRisposta.Confermato)
                .Select(c => c.Player.UserId)
                .ToList();

            var accodati = 0;

            if (daSollecitare.Count > 0)
            {
                accodati += await notifications.QueueAsync(
                    NotificationKind.PromemoriaPartita,
                    daSollecitare,
                    titolo: $"{match.Team.Nome}: non hai ancora risposto",
                    corpo: $"{avversario}, {quando}{dove}. Fai sapere se ci sei.",
                    url: $"/match/{match.Id}",
                    tag: $"promemoria-{match.Id}",
                    teamId: match.TeamId,
                    scheduledFor: promemoria > adesso ? promemoria : null,
                    ct: ct);
            }

            if (daRicordare.Count > 0)
            {
                accodati += await notifications.QueueAsync(
                    NotificationKind.PromemoriaPartita,
                    daRicordare,
                    titolo: $"{match.Team.Nome}: si gioca {quando}",
                    corpo: $"{avversario}{dove}. Ci vediamo in campo.",
                    url: $"/match/{match.Id}",
                    tag: $"promemoria-{match.Id}",
                    teamId: match.TeamId,
                    scheduledFor: promemoria > adesso ? promemoria : null,
                    ct: ct);
            }

            // Si marca anche se non e' stato accodato nulla (nessuno con le
            // notifiche attive): altrimenti si riprova a ogni giro per giorni.
            match.PromemoriaInviatoAt = adesso;
            accodatiTotali += accodati;
        }

        if (context.ChangeTracker.HasChanges())
        {
            await context.SaveChangesAsync(ct);
            if (accodatiTotali > 0)
                _logger.LogInformation("Promemoria partita: {N} notifiche accodate", accodatiTotali);
        }
    }
}
