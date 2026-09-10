using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IMatchPaymentService
{
    Task<MatchPaymentPreviewDto> PreviewAsync(int matchId, int teamId);
    Task<ConfirmMatchPaymentResultDto> ConfirmAsync(
        int matchId, ConfirmMatchPaymentDto dto, int adminPlayerId, int teamId);
}

/// <summary>
/// Incasso di una singola partita: propone chi deve pagare e, dopo la conferma
/// dell'admin, crea gli addebiti e manda le notifiche.
///
/// Il flusso e' volutamente guidato dall'admin e non automatico: solo lui sa se
/// le presenze sono davvero complete, e l'utente ha chiesto di poter scegliere.
/// Come effetto collaterale non serve ne' una schedulazione nella coda notifiche
/// ne' un "admin di sistema" per firmare i pagamenti.
/// </summary>
public class MatchPaymentService : IMatchPaymentService
{
    private readonly ApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<MatchPaymentService> _logger;

    public MatchPaymentService(
        ApplicationDbContext context,
        INotificationService notifications,
        ILogger<MatchPaymentService> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    public async Task<MatchPaymentPreviewDto> PreviewAsync(int matchId, int teamId)
    {
        var (match, team) = await LoadAsync(matchId, teamId);

        var attendances = await _context.MatchAttendances
            .Include(a => a.Player)
            .Where(a => a.MatchId == matchId)
            .ToListAsync();

        var giaAddebitati = await _context.PlayerPayments
            .Where(p => p.MatchId == matchId && p.PlayerId != null)
            .Select(p => p.PlayerId!.Value)
            .ToListAsync();

        var playerIds = attendances.Select(a => a.PlayerId).ToList();
        var arretrati = await ArretratiAsync(playerIds);

        var preview = new MatchPaymentPreviewDto
        {
            MatchId = match.Id,
            Partita = DescriviPartita(match),
            Data = match.Data,
            Stato = match.Stato.ToString(),
            CostoPartita = team.CostoPartita,
            MinutiMinimiPerAddebito = team.MinutiMinimiPerAddebito,
            GiaGestita = giaAddebitati.Count > 0,
            PresenzeDaRegistrare = attendances.All(a => !a.Presente),
            PresenzeBloccate = match.Stato == StatoPartita.Conclusa
        };

        foreach (var attendance in attendances.OrderBy(a => a.Player.Nome))
        {
            var regime = RegimiPagamento.Effettivo(
                attendance.Player.RegimePagamento, team.RegimePagamentoDefault);

            var candidato = new MatchPaymentCandidateDto
            {
                PlayerId = attendance.PlayerId,
                Nome = attendance.Player.Nome,
                Soprannome = attendance.Player.Soprannome,
                Regime = regime.ToString(),
                Presente = attendance.Presente,
                HaGiocato = attendance.HaGiocato,
                MinutiGiocati = attendance.MinutiGiocati,
                GiaAddebitato = giaAddebitati.Contains(attendance.PlayerId),
                ImportoProposto = team.CostoPartita,
                ArretratoAttuale = arretrati.TryGetValue(attendance.PlayerId, out var a) ? a : 0m
            };

            var (preselezionato, motivo) = Valuta(candidato, regime, team.MinutiMinimiPerAddebito);
            candidato.Preselezionato = preselezionato;
            candidato.Motivo = motivo;

            preview.Candidati.Add(candidato);
        }

        return preview;
    }

    public async Task<ConfirmMatchPaymentResultDto> ConfirmAsync(
        int matchId, ConfirmMatchPaymentDto dto, int adminPlayerId, int teamId)
    {
        var (match, team) = await LoadAsync(matchId, teamId);

        var richiesti = dto.PlayerIds.Distinct().ToList();
        if (richiesti.Count == 0)
            throw new BadRequestException("Nessun giocatore selezionato");

        var players = await _context.Players
            .Where(p => richiesti.Contains(p.Id) && p.TeamId == teamId)
            .ToListAsync();

        // Ci si arriva riaprendo e riconcludendo la partita: chi e' gia' stato
        // addebitato va saltato, non deve far esplodere l'indice unique.
        var giaAddebitati = await _context.PlayerPayments
            .Where(p => p.MatchId == matchId && p.PlayerId != null
                        && richiesti.Contains(p.PlayerId.Value))
            .Select(p => p.PlayerId!.Value)
            .ToListAsync();

        // Congelata alla creazione: la FK e' SetNull, quindi se la partita
        // viene cancellata questa resta l'unica traccia di cosa si e' pagato.
        var descrizione = DescriviPartita(match);
        var adminNome = await _context.Players
            .Where(p => p.Id == adminPlayerId).Select(p => p.Nome).FirstOrDefaultAsync();
        var result = new ConfirmMatchPaymentResultDto();
        var creati = new List<PlayerPayment>();

        foreach (var player in players)
        {
            if (giaAddebitati.Contains(player.Id))
            {
                result.Saltati++;
                continue;
            }

            var importo = RisolviImporto(dto, player.Id, team.CostoPartita);
            if (importo <= 0)
            {
                result.Saltati++;
                continue;
            }

            var payment = new PlayerPayment
            {
                TeamId = teamId,
                // La partita porta con se la sua stagione: l addebito appartiene a quella
                SeasonId = match.SeasonId,
                PlayerId = player.Id,
                NomeGiocatore = player.Nome,
                MatchId = matchId,
                Tipo = TipoPagamento.Partita,
                Descrizione = descrizione,
                Importo = importo,
                DataPagamento = match.Data.Date,
                Pagato = false,
                AdminId = adminPlayerId,
                AdminNome = adminNome,
                CreatedAt = DateTime.UtcNow
            };
            _context.PlayerPayments.Add(payment);
            creati.Add(payment);

            result.Addebitati++;
            result.TotaleAddebitato += importo;
        }

        result.Saltati += richiesti.Count - players.Count;

        if (result.Addebitati == 0)
        {
            _logger.LogInformation(
                "Incasso partita {MatchId}: nessun addebito creato ({Saltati} saltati)", matchId, result.Saltati);
            result.Pagamenti = await PagamentiPartitaAsync(matchId);
            return result;
        }

        await _context.SaveChangesAsync();

        if (dto.InviaNotifica)
            result.NotificheAccodate = await NotificaAsync(team, match, creati, players);

        _logger.LogInformation(
            "Incasso partita {MatchId}: {Addebitati} addebiti per {Totale}, {Notifiche} notifiche",
            matchId, result.Addebitati, result.TotaleAddebitato, result.NotificheAccodate);

        result.Pagamenti = await PagamentiPartitaAsync(matchId);
        return result;
    }

    // ---------------------------------------------------------------- interni

    /// <summary>
    /// Carica partita e squadra verificando che la partita sia di quel team.
    /// Il controllo va fatto qui: le route /api/matches/{matchId}/... non hanno
    /// un parametro teamId, quindi TeamAuthorizationMiddleware non le protegge.
    /// </summary>
    private async Task<(Match Match, Team Team)> LoadAsync(int matchId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId)
            ?? throw new NotFoundException("Partita", matchId);

        if (match.TeamId != teamId)
            throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var team = await _context.Teams.FindAsync(teamId)
            ?? throw new NotFoundException("Team", teamId);

        return (match, team);
    }

    /// <summary>
    /// Chi proporre di addebitare. `MinutiGiocati` e' quasi sempre vuoto (si
    /// compila solo dal dialogo statistiche), percio' null conta come soglia
    /// superata e si sta al segnale forte `HaGiocato`: trattarlo come "sotto
    /// soglia" renderebbe la preselezione sempre vuota e quindi inutile.
    /// </summary>
    private static (bool Preselezionato, string? Motivo) Valuta(
        MatchPaymentCandidateDto candidato, RegimePagamento regime, int minutiMinimi)
    {
        if (candidato.GiaAddebitato) return (false, "gia' addebitato");
        if (regime != RegimePagamento.APartita) return (false, "paga a stagione");
        if (!candidato.Presente) return (false, "non presente");
        if (!candidato.HaGiocato) return (false, "non ha giocato");

        if (minutiMinimi > 0 && candidato.MinutiGiocati.HasValue && candidato.MinutiGiocati < minutiMinimi)
            return (false, $"solo {candidato.MinutiGiocati} minuti");

        return (true, null);
    }

    private static decimal RisolviImporto(ConfirmMatchPaymentDto dto, int playerId, decimal costoPartita)
    {
        if (dto.ImportiPerGiocatore != null && dto.ImportiPerGiocatore.TryGetValue(playerId, out var perGiocatore))
            return perGiocatore;
        return dto.Importo ?? costoPartita;
    }

    private static string DescriviPartita(Match match)
    {
        var avversario = string.IsNullOrWhiteSpace(match.Titolo) ? null : $" vs {match.Titolo}";
        return $"Partita - Giornata {match.NumeroGiornata}{avversario} - {match.Data:dd/MM/yyyy}";
    }

    private async Task<Dictionary<int, decimal>> ArretratiAsync(List<int> playerIds)
    {
        if (playerIds.Count == 0) return new Dictionary<int, decimal>();

        return await _context.PlayerPayments
            .Where(p => p.PlayerId != null && playerIds.Contains(p.PlayerId.Value) && !p.Pagato)
            .GroupBy(p => p.PlayerId!.Value)
            .Select(g => new { PlayerId = g.Key, Totale = g.Sum(x => x.Importo) })
            .ToDictionaryAsync(x => x.PlayerId, x => x.Totale);
    }

    private async Task<int> NotificaAsync(
        Team team, Match match, List<PlayerPayment> creati, List<Player> players)
    {
        // Il totale arretrato si rilegge dopo il salvataggio, cosi' comprende
        // l'addebito appena creato e le eventuali quote ancora aperte.
        var arretrati = await ArretratiAsync(creati.Select(c => c.PlayerId!.Value).ToList());
        var accodate = 0;

        foreach (var payment in creati)
        {
            var player = players.First(p => p.Id == payment.PlayerId);
            var totale = arretrati.TryGetValue(player.Id, out var t) ? t : payment.Importo;

            var corpo = totale > payment.Importo
                ? $"Giornata {match.NumeroGiornata}: {PaymentService.Euro(payment.Importo)}. " +
                  $"In tutto hai {PaymentService.Euro(totale)} da saldare."
                : $"Giornata {match.NumeroGiornata}: {PaymentService.Euro(payment.Importo)} da saldare.";

            accodate += await _notifications.QueueAsync(
                NotificationKind.PagamentoDovuto,
                new[] { player.UserId },
                titolo: $"{team.Nome}: quota partita",
                corpo: corpo,
                url: "/payments",
                tag: $"partita-pagamento-{match.Id}",
                teamId: team.Id);
        }

        return accodate;
    }

    private async Task<List<PlayerPaymentDto>> PagamentiPartitaAsync(int matchId)
    {
        var payments = await _context.PlayerPayments
            .Where(p => p.MatchId == matchId)
            .OrderBy(p => p.NomeGiocatore)
            .ToListAsync();

        return payments.Select(p => new PlayerPaymentDto
        {
            Id = p.Id, PlayerId = p.PlayerId ?? 0, NomeGiocatore = p.NomeGiocatore,
            Descrizione = p.Descrizione, Importo = p.Importo, DataPagamento = p.DataPagamento,
            Pagato = p.Pagato, Note = p.Note, AdminNome = p.AdminNome ?? string.Empty,
            CreatedAt = p.CreatedAt, Tipo = p.Tipo.ToString(), MatchId = p.MatchId,
            DichiaratoPagatoAt = p.DichiaratoPagatoAt, GiocatoreRimosso = p.PlayerId == null
        }).ToList();
    }
}
