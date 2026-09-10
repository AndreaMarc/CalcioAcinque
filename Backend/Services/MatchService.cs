using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Matches;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IMatchService
{
    Task<List<MatchDto>> GetAllByTeamAsync(int teamId, StatoPartita? stato = null, int? seasonId = null);
    Task<MatchDetailDto> GetByIdAsync(int teamId, int matchId);
    Task<MatchDto> CreateAsync(int teamId, CreateMatchDto dto);
    Task<MatchDto> UpdateAsync(int teamId, int matchId, UpdateMatchDto dto);
    Task DeleteAsync(int teamId, int matchId);
    Task<MatchDto> UpdateStatoAsync(int teamId, int matchId, StatoPartita stato);
}

public class MatchService : IMatchService
{
    private readonly ApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ISeasonService _seasons;

    public MatchService(
        ApplicationDbContext context,
        INotificationService notifications,
        ISeasonService seasons)
    {
        _context = context;
        _notifications = notifications;
        _seasons = seasons;
    }

    public async Task<List<MatchDto>> GetAllByTeamAsync(int teamId, StatoPartita? stato = null, int? seasonId = null)
    {
        var query = _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances).Where(m => m.TeamId == teamId);
        if (stato.HasValue) query = query.Where(m => m.Stato == stato.Value);

        // Senza stagione richiesta si mostra quella aperta: chiudere una stagione
        // deve archiviarla, non lasciarla mescolata alle partite nuove.
        // Le partite senza stagione (dati anteriori) restano visibili in quella corrente.
        var stagione = seasonId ?? (await _seasons.GetCorrenteAsync(teamId))?.Id;
        if (stagione.HasValue)
            query = query.Where(m => m.SeasonId == stagione.Value || m.SeasonId == null);
        var matches = await query.OrderBy(m => m.NumeroGiornata).ToListAsync();
        return matches.Select(MapToDto).ToList();
    }

    public async Task<MatchDetailDto> GetByIdAsync(int teamId, int matchId)
    {
        var match = await _context.Matches
            .Include(m => m.Convocations).ThenInclude(c => c.Player)
            .Include(m => m.Attendances).ThenInclude(a => a.Player)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);

        return new MatchDetailDto
        {
            Id = match.Id, TeamId = match.TeamId, Data = match.Data, Ora = match.Ora.ToString(@"hh\:mm"),
            Luogo = match.Luogo, Titolo = match.Titolo, NumeroGiornata = match.NumeroGiornata, Stato = match.Stato.ToString(),
            Note = match.Note, CreatedAt = match.CreatedAt,
            TotaleConvocati = match.Convocations.Count,
            TotaleConfermati = match.Convocations.Count(c => c.StatoRisposta == StatoRisposta.Confermato),
            TotalePresenti = match.Attendances.Count(a => a.Presente),
            TotaleHannoGiocato = match.Attendances.Count(a => a.HaGiocato),
            Convocazioni = match.Convocations.Select(c => new ConvocationSummaryDto
            {
                PlayerId = c.PlayerId, NomeGiocatore = c.Player.Nome, Soprannome = c.Player.Soprannome,
                StatoRisposta = c.StatoRisposta.ToString(), DataRisposta = c.DataRisposta
            }).ToList(),
            Presenze = match.Attendances.Select(a => new AttendanceSummaryDto
            {
                PlayerId = a.PlayerId, NomeGiocatore = a.Player.Nome, Soprannome = a.Player.Soprannome,
                Convocato = a.Convocato, Presente = a.Presente, HaGiocato = a.HaGiocato, GettoneConsumato = a.GettoneConsumato
            }).ToList()
        };
    }

    public async Task<MatchDto> CreateAsync(int teamId, CreateMatchDto dto)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Team", teamId);
        if (!TimeSpan.TryParse(dto.Ora, out var ora)) throw new BadRequestException("Formato ora non valido. Usare HH:mm");

        var stagione = await _seasons.GetOrCreateCorrenteAsync(teamId);
        var match = new Match { TeamId = teamId, SeasonId = stagione.Id, Data = dto.Data.Date, Ora = ora, Luogo = dto.Luogo, Titolo = dto.Titolo, NumeroGiornata = dto.NumeroGiornata, Note = dto.Note, Stato = StatoPartita.Programmata, CreatedAt = DateTime.UtcNow };
        _context.Matches.Add(match);
        await _context.SaveChangesAsync();
        return MapToDto(match);
    }

    public async Task<MatchDto> UpdateAsync(int teamId, int matchId, UpdateMatchDto dto)
    {
        var match = await _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);

        // Solo data, ora e campo giustificano una notifica: cambiare le note no
        var primaData = match.Data;
        var primaOra = match.Ora;
        var primaLuogo = match.Luogo;

        if (dto.Data.HasValue) match.Data = dto.Data.Value.Date;
        if (dto.Ora != null && TimeSpan.TryParse(dto.Ora, out var ora)) match.Ora = ora;
        if (dto.Luogo != null) match.Luogo = dto.Luogo;
        if (dto.Titolo != null) match.Titolo = dto.Titolo;
        if (dto.NumeroGiornata.HasValue) match.NumeroGiornata = dto.NumeroGiornata.Value;
        if (dto.Note != null) match.Note = dto.Note;
        await _context.SaveChangesAsync();

        var logistica = match.Data != primaData || match.Ora != primaOra || match.Luogo != primaLuogo;
        if (logistica)
        {
            // La partita si e spostata: il promemoria gia accodato punterebbe
            // all orario vecchio, quindi si butta e si riapre la porta a uno nuovo.
            var vecchi = await _context.NotificationOutbox
                .Where(n => n.Tag == $"promemoria-{match.Id}"
                            && n.Stato == NotificationStatus.InCoda)
                .ToListAsync();
            if (vecchi.Count > 0) _context.NotificationOutbox.RemoveRange(vecchi);

            match.PromemoriaInviatoAt = null;
            await _context.SaveChangesAsync();

            if (match.Convocations.Count > 0)
                await NotificaSpostamentoAsync(match, teamId);
        }

        return MapToDto(match);
    }

    /// <summary>Avvisa solo chi era gia' stato convocato: agli altri non cambia nulla.</summary>
    private async Task NotificaSpostamentoAsync(Match match, int teamId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        var convocatiUserIds = await _context.Convocations
            .Where(c => c.MatchId == match.Id)
            .Select(c => c.Player.UserId)
            .ToListAsync();

        var dove = string.IsNullOrWhiteSpace(match.Luogo) ? string.Empty : $" - {match.Luogo}";

        await _notifications.QueueAsync(
            NotificationKind.PartitaAggiornata,
            convocatiUserIds,
            titolo: team != null ? $"{team.Nome}: partita spostata" : "Partita spostata",
            corpo: $"Giornata {match.NumeroGiornata}: ora {match.Data:dd/MM} alle {match.Ora:hh\\:mm}{dove}.",
            url: $"/match/{match.Id}",
            tag: $"partita-{match.Id}",
            teamId: teamId);
    }

    public async Task DeleteAsync(int teamId, int matchId)
    {
        var match = await _context.Matches
            .Include(m => m.Attendances).ThenInclude(a => a.Player)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);

        // Ripristina gettoni consumati per questa partita
        foreach (var att in match.Attendances.Where(a => a.GettoneConsumato))
        {
            att.Player.GettoniConsumati -= 1;
        }

        _context.Matches.Remove(match);
        await _context.SaveChangesAsync();
    }

    // Transizioni di stato consentite. "Conclusa" può tornare solo a "InCorso"
    // (riapertura per correggere presenze/gettoni), non a stati precedenti.
    private static readonly Dictionary<StatoPartita, StatoPartita[]> _transizioni = new()
    {
        [StatoPartita.Programmata] = new[] { StatoPartita.ConvocazioniInviate, StatoPartita.InCorso, StatoPartita.Conclusa },
        [StatoPartita.ConvocazioniInviate] = new[] { StatoPartita.Programmata, StatoPartita.InCorso, StatoPartita.Conclusa },
        [StatoPartita.InCorso] = new[] { StatoPartita.Programmata, StatoPartita.ConvocazioniInviate, StatoPartita.Conclusa },
        [StatoPartita.Conclusa] = new[] { StatoPartita.InCorso },
    };

    public async Task<MatchDto> UpdateStatoAsync(int teamId, int matchId, StatoPartita stato)
    {
        var match = await _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);

        if (match.Stato != stato &&
            (!_transizioni.TryGetValue(match.Stato, out var consentiti) || !consentiti.Contains(stato)))
        {
            throw new BadRequestException(
                $"Transizione di stato non valida: {match.Stato} → {stato}. " +
                "Per modificare una partita conclusa riaprila prima (Conclusa → In corso).");
        }

        match.Stato = stato;
        await _context.SaveChangesAsync();
        return MapToDto(match);
    }

    private static MatchDto MapToDto(Match m) => new()
    {
        Id = m.Id, TeamId = m.TeamId, Data = m.Data, Ora = m.Ora.ToString(@"hh\:mm"), Luogo = m.Luogo,
        Titolo = m.Titolo, NumeroGiornata = m.NumeroGiornata, Stato = m.Stato.ToString(), Note = m.Note, CreatedAt = m.CreatedAt,
        TotaleConvocati = m.Convocations?.Count ?? 0,
        TotaleConfermati = m.Convocations?.Count(c => c.StatoRisposta == StatoRisposta.Confermato) ?? 0,
        TotalePresenti = m.Attendances?.Count(a => a.Presente) ?? 0,
        TotaleHannoGiocato = m.Attendances?.Count(a => a.HaGiocato) ?? 0
    };
}
