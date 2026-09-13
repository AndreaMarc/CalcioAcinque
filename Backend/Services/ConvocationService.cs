using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Convocations;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IConvocationService
{
    Task<List<ConvocationDto>> GetByMatchAsync(int matchId, int teamId);
    Task<List<ConvocationDto>> SendConvocationsAsync(int matchId, SendConvocationsDto dto, int teamId);
    Task<ConvocationDto> RespondAsync(int convocationId, int playerId, RespondConvocationDto dto);
    Task<List<ConvocationDto>> GetPendingByPlayerAsync(int playerId, int teamId);
    Task RevokeAsync(int convocationId, int teamId);
}

public class ConvocationService : IConvocationService
{
    private readonly ApplicationDbContext _context;
    private readonly INotificationService _notifications;

    public ConvocationService(ApplicationDbContext context, INotificationService notifications)
    {
        _context = context;
        _notifications = notifications;
    }

    public async Task<List<ConvocationDto>> GetByMatchAsync(int matchId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var convocations = await _context.Convocations.Include(c => c.Player).Include(c => c.Match)
            .Where(c => c.MatchId == matchId).OrderBy(c => c.Player.Nome).ToListAsync();
        return convocations.Select(MapToDto).ToList();
    }

    public async Task<List<ConvocationDto>> SendConvocationsAsync(int matchId, SendConvocationsDto dto, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var team = await _context.Teams.FindAsync(teamId);
        if (team?.MaxConvocati is int max)
        {
            var giaConvocati = await _context.Convocations
                .Where(c => c.MatchId == matchId)
                .Select(c => c.PlayerId)
                .ToListAsync();
            var daAggiungere = dto.PlayerIds.Distinct().Count(id => !giaConvocati.Contains(id));

            if (giaConvocati.Count + daAggiungere > max)
                throw new BusinessException(
                    $"{team.Nome} ammette al massimo {max} convocati per partita " +
                    $"({giaConvocati.Count} gia' convocati, ne stai aggiungendo {daAggiungere})");
        }

        // Una sola query invece di due per giocatore (la lista e' piccola ma il ciclo era N+1)
        var richiesti = dto.PlayerIds.Distinct().ToList();
        var giaConvocatiIds = await _context.Convocations
            .Where(c => c.MatchId == matchId && richiesti.Contains(c.PlayerId))
            .Select(c => c.PlayerId)
            .ToListAsync();
        var players = await _context.Players
            .Where(p => richiesti.Contains(p.Id) && p.TeamId == teamId)
            .ToListAsync();

        var nuovi = players.Where(p => !giaConvocatiIds.Contains(p.Id)).ToList();

        foreach (var player in nuovi)
        {
            _context.Convocations.Add(new Convocation { MatchId = matchId, PlayerId = player.Id, StatoRisposta = StatoRisposta.InAttesa, DataConvocazione = DateTime.UtcNow, NotificaInviata = true });
            _context.MatchAttendances.Add(new MatchAttendance { MatchId = matchId, PlayerId = player.Id, Convocato = true });
        }

        if (match.Stato == StatoPartita.Programmata) match.Stato = StatoPartita.ConvocazioniInviate;
        await _context.SaveChangesAsync();

        await NotificaConvocatiAsync(match, team, nuovi);

        return await GetByMatchAsync(matchId, teamId);
    }

    public async Task<ConvocationDto> RespondAsync(int convocationId, int playerId, RespondConvocationDto dto)
    {
        var convocation = await _context.Convocations.Include(c => c.Player)
            .Include(c => c.Match).ThenInclude(m => m.Team)
            .FirstOrDefaultAsync(c => c.Id == convocationId);
        if (convocation == null) throw new NotFoundException("Convocazione", convocationId);
        if (convocation.PlayerId != playerId) throw new UnauthorizedException("Non puoi rispondere alla convocazione di un altro giocatore");
        if (!Enum.TryParse<StatoRisposta>(dto.Risposta, true, out var stato) || stato == StatoRisposta.InAttesa)
            throw new BadRequestException("Risposta non valida. Usare 'Confermato' o 'NonDisponibile'");

        var eraGiaForfait = convocation.StatoRisposta == StatoRisposta.NonDisponibile;
        convocation.StatoRisposta = stato;
        convocation.DataRisposta = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        if (stato == StatoRisposta.NonDisponibile && !eraGiaForfait)
            await NotificaForfaitAsync(convocation);

        return MapToDto(convocation);
    }

    /// <summary>
    /// Toglie una convocazione (Campo): libera il posto per un sostituto. La
    /// presenza creata all'invio viene rimossa se non e' gia' stata segnata.
    /// </summary>
    public async Task RevokeAsync(int convocationId, int teamId)
    {
        var convocation = await _context.Convocations
            .Include(c => c.Match).ThenInclude(m => m.Team)
            .Include(c => c.Player)
            .FirstOrDefaultAsync(c => c.Id == convocationId);
        if (convocation == null) throw new NotFoundException("Convocazione", convocationId);
        if (convocation.Match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        if (convocation.Match.Stato == StatoPartita.Conclusa)
            throw new BusinessException("La partita e' conclusa: la lista dei convocati non si tocca piu'");

        var attendance = await _context.MatchAttendances
            .FirstOrDefaultAsync(a => a.MatchId == convocation.MatchId && a.PlayerId == convocation.PlayerId);
        if (attendance != null)
        {
            if (attendance.Presente)
                throw new BusinessException("Il giocatore e' gia' segnato presente: prima togli la presenza dal Match Day");
            _context.MatchAttendances.Remove(attendance);
        }
        _context.Convocations.Remove(convocation);
        await _context.SaveChangesAsync();

        // Chi esce dalla lista lo deve sapere dall'app, non dal gruppo: stessa
        // preferenza delle convocazioni, cosi' chi le ha spente non riceve nulla
        var match = convocation.Match;
        var quando = $"{match.Data:dd/MM}" + (match.Ora == default ? string.Empty : $" alle {match.Ora:hh\\:mm}");
        await _notifications.QueueAsync(
            NotificationKind.Convocazione,
            new[] { convocation.Player.UserId },
            titolo: $"{match.Team.Nome}: convocazione revocata",
            corpo: $"Giornata {match.NumeroGiornata}, {quando}: non sei piu' tra i convocati. Se hai dubbi, chiedi al mister.",
            url: $"/match/{match.Id}",
            tag: $"revoca-{match.Id}-{convocation.PlayerId}",
            teamId: match.TeamId);
    }

    /// <summary>
    /// Un forfait va saputo subito da chi deve trovare il sostituto: mister e
    /// admin ricevono chi ha detto di no e quanti disponibili non convocati ci sono.
    /// </summary>
    private async Task NotificaForfaitAsync(Convocation convocation)
    {
        var match = convocation.Match;
        var team = match.Team;
        var convocatiIds = await _context.Convocations
            .Where(c => c.MatchId == match.Id)
            .Select(c => c.PlayerId)
            .ToListAsync();
        var disponibiliNonConvocati = await _context.PlayerAvailabilities
            .CountAsync(a => a.MatchId == match.Id && a.Disponibile && !convocatiIds.Contains(a.PlayerId));

        var staff = await _context.Players
            .Where(p => p.TeamId == match.TeamId
                        && (p.Ruolo == UserRole.Admin || p.Ruolo == UserRole.Mister)
                        && p.Id != convocation.PlayerId)
            .Select(p => p.UserId)
            .ToListAsync();
        if (staff.Count == 0) return;

        var chi = string.IsNullOrWhiteSpace(convocation.Player.Soprannome)
            ? convocation.Player.Nome
            : convocation.Player.Soprannome;
        var quando = $"{match.Data:dd/MM}" + (match.Ora == default ? string.Empty : $" alle {match.Ora:hh\\:mm}");
        var sostituti = disponibiliNonConvocati == 0
            ? "Nessun altro disponibile al momento."
            : $"{disponibiliNonConvocati} disponibil{(disponibiliNonConvocati == 1 ? "e" : "i")} non convocat{(disponibiliNonConvocati == 1 ? "o" : "i")}: convoca un sostituto.";

        await _notifications.QueueAsync(
            NotificationKind.Forfait,
            staff,
            titolo: $"{team.Nome}: {chi} ha dato forfait",
            corpo: $"Giornata {match.NumeroGiornata}, {quando}. {sostituti}",
            url: $"/match/{match.Id}/convocations",
            tag: $"forfait-{match.Id}",
            teamId: match.TeamId);
    }

    public async Task<List<ConvocationDto>> GetPendingByPlayerAsync(int playerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var convocations = await _context.Convocations.Include(c => c.Player).Include(c => c.Match)
            .Where(c => c.PlayerId == playerId && c.StatoRisposta == StatoRisposta.InAttesa)
            .OrderBy(c => c.Match.Data).ToListAsync();
        return convocations.Select(MapToDto).ToList();
    }

    /// <summary>
    /// Avvisa i nuovi convocati. Il titolo porta il nome della squadra perche' con
    /// due squadre nella stessa societa' "Sei convocato" da solo e' ambiguo.
    /// </summary>
    private async Task NotificaConvocatiAsync(Match match, Team? team, List<Player> nuovi)
    {
        if (nuovi.Count == 0) return;

        var quando = $"{match.Data:dd/MM}" + (match.Ora == default ? string.Empty : $" alle {match.Ora:hh\\:mm}");
        var dove = string.IsNullOrWhiteSpace(match.Luogo) ? string.Empty : $" - {match.Luogo}";
        var avversario = string.IsNullOrWhiteSpace(match.Titolo)
            ? $"Giornata {match.NumeroGiornata}"
            : $"vs {match.Titolo}";

        await _notifications.QueueAsync(
            NotificationKind.Convocazione,
            nuovi.Select(p => p.UserId),
            titolo: team != null ? $"{team.Nome}: sei convocato" : "Sei convocato",
            corpo: $"{avversario} - {quando}{dove}. Conferma la tua presenza.",
            url: $"/match/{match.Id}",
            tag: $"convocazione-{match.Id}",
            teamId: match.TeamId);
    }

    private static ConvocationDto MapToDto(Convocation c) => new()
    {
        Id = c.Id, MatchId = c.MatchId, PlayerId = c.PlayerId, NomeGiocatore = c.Player.Nome,
        Soprannome = c.Player.Soprannome, NumeroMaglia = c.Player.NumeroMaglia,
        StatoRisposta = c.StatoRisposta.ToString(),
        DataConvocazione = c.DataConvocazione, DataRisposta = c.DataRisposta,
        DataPartita = c.Match?.Data, OraPartita = c.Match?.Ora.ToString(@"hh\:mm"),
        LuogoPartita = c.Match?.Luogo, NumeroGiornata = c.Match?.NumeroGiornata
    };
}
