using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Stats;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IStatsService
{
    Task<TeamStatsDto> GetTeamStatsAsync(int teamId, int? seasonId = null);
    Task<PlayerStatsDto> GetPlayerStatsAsync(int playerId, int teamId, int? seasonId = null);
}

public class StatsService : IStatsService
{
    private readonly ApplicationDbContext _context;

    public StatsService(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Stagione da usare: quella richiesta, altrimenti quella aperta. Null se la
    /// squadra non ha stagioni (dati legacy): allora si contano tutte le partite.
    /// </summary>
    private async Task<Season?> ResolveSeasonAsync(int teamId, int? seasonId)
    {
        if (seasonId.HasValue)
            return await _context.Seasons.FirstOrDefaultAsync(s => s.Id == seasonId.Value && s.TeamId == teamId)
                   ?? throw new NotFoundException("Stagione", seasonId.Value);
        return await _context.Seasons
            .Where(s => s.TeamId == teamId && !s.Chiusa)
            .OrderByDescending(s => s.Id)
            .FirstOrDefaultAsync();
    }

    public async Task<TeamStatsDto> GetTeamStatsAsync(int teamId, int? seasonId = null)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Squadra", teamId);

        var season = await ResolveSeasonAsync(teamId, seasonId);

        // Partite concluse del team, nella stagione scelta
        var matchQuery = _context.Matches.Where(m => m.TeamId == teamId && m.Stato == StatoPartita.Conclusa);
        if (season != null) matchQuery = matchQuery.Where(m => m.SeasonId == season.Id);
        var matchIds = await matchQuery
            .OrderBy(m => m.Data)
            .Select(m => new { m.Id, m.NumeroGiornata, m.Data })
            .ToListAsync();

        var ids = matchIds.Select(m => m.Id).ToList();
        var allAttendances = await _context.MatchAttendances
            .Include(a => a.Player)
            .Where(a => ids.Contains(a.MatchId))
            .ToListAsync();
        var voti = await _context.MatchVotes.Where(v => ids.Contains(v.MatchId)).ToListAsync();
        var convocazioni = await _context.Convocations.Where(c => ids.Contains(c.MatchId)).ToListAsync();
        // Vince l'MVP chi ha piu' voti nella partita (a pari merito vincono tutti)
        var vincitori = voti
            .GroupBy(v => v.MatchId)
            .SelectMany(g =>
            {
                var conteggi = g.GroupBy(v => v.VotedPlayerId).Select(x => new { PlayerId = x.Key, N = x.Count() }).ToList();
                var max = conteggi.Max(x => x.N);
                return conteggi.Where(x => x.N == max).Select(x => x.PlayerId);
            })
            .GroupBy(p => p)
            .ToDictionary(g => g.Key, g => g.Count());

        // Statistiche per giocatore
        var playerGroups = allAttendances
            .GroupBy(a => a.PlayerId)
            .Select(g => new PlayerStatsDto
            {
                PlayerId = g.Key,
                NomeGiocatore = g.First().Player.Nome,
                Soprannome = g.First().Player.Soprannome,
                PartitePresente = g.Count(a => a.Presente),
                PartiteGiocate = g.Count(a => a.HaGiocato),
                TotaleMinutiGiocati = g.Sum(a => a.MinutiGiocati ?? 0),
                TotaleGoal = g.Sum(a => a.Goal ?? 0),
                TotaleAssist = g.Sum(a => a.Assist ?? 0),
                TotaleAutogoal = g.Sum(a => a.Autogoal ?? 0),
                TotaleAmmonizioni = g.Sum(a => a.Ammonizioni ?? 0),
                TotaleEspulsioni = g.Sum(a => a.Espulsioni ?? 0),
                TotaleGoalSubiti = g.Sum(a => a.GoalSubiti ?? 0),
                MediaGoalPartita = g.Count(a => a.HaGiocato) > 0
                    ? Math.Round((double)g.Sum(a => a.Goal ?? 0) / g.Count(a => a.HaGiocato), 2) : 0,
                MediaAssistPartita = g.Count(a => a.HaGiocato) > 0
                    ? Math.Round((double)g.Sum(a => a.Assist ?? 0) / g.Count(a => a.HaGiocato), 2) : 0,
                VotiMvp = voti.Count(v => v.VotedPlayerId == g.Key),
                PartiteMvp = vincitori.GetValueOrDefault(g.Key),
            })
            .Select(p => ConAffidabilita(p, convocazioni.Where(c => c.PlayerId == p.PlayerId)))
            .OrderByDescending(p => p.TotaleGoal)
            .ThenByDescending(p => p.TotaleAssist)
            .ThenByDescending(p => p.PartiteGiocate)
            .ToList();

        // Storico partite
        var storicoPartite = matchIds.Select(m =>
        {
            var matchAtt = allAttendances.Where(a => a.MatchId == m.Id).ToList();
            return new MatchStatsDto
            {
                MatchId = m.Id,
                NumeroGiornata = m.NumeroGiornata,
                Data = m.Data,
                GoalFatti = matchAtt.Sum(a => a.Goal ?? 0),
                GoalSubiti = matchAtt.Sum(a => a.GoalSubiti ?? 0),
                Presenti = matchAtt.Count(a => a.Presente),
            };
        }).ToList();

        return new TeamStatsDto
        {
            TeamId = teamId,
            SeasonId = season?.Id,
            SeasonNome = season?.Nome,
            TotalePartite = matchIds.Count,
            Vittorie = storicoPartite.Count(m => m.GoalFatti > m.GoalSubiti),
            Pareggi = storicoPartite.Count(m => m.GoalFatti == m.GoalSubiti),
            Sconfitte = storicoPartite.Count(m => m.GoalFatti < m.GoalSubiti),
            TotaleGoal = playerGroups.Sum(p => p.TotaleGoal),
            TotaleAssist = playerGroups.Sum(p => p.TotaleAssist),
            TotaleAutogoal = playerGroups.Sum(p => p.TotaleAutogoal),
            TotaleAmmonizioni = playerGroups.Sum(p => p.TotaleAmmonizioni),
            TotaleEspulsioni = playerGroups.Sum(p => p.TotaleEspulsioni),
            TotaleGoalSubiti = playerGroups.Sum(p => p.TotaleGoalSubiti),
            Classifica = playerGroups,
            StoricoPartite = storicoPartite,
        };
    }

    public async Task<PlayerStatsDto> GetPlayerStatsAsync(int playerId, int teamId, int? seasonId = null)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var season = await ResolveSeasonAsync(teamId, seasonId);
        var attQuery = _context.MatchAttendances
            .Include(a => a.Match)
            .Where(a => a.PlayerId == playerId && a.Match.Stato == StatoPartita.Conclusa);
        if (season != null) attQuery = attQuery.Where(a => a.Match.SeasonId == season.Id);
        var attendances = await attQuery.ToListAsync();
        var matchIds = attendances.Select(a => a.MatchId).ToList();

        var votiRicevuti = await _context.MatchVotes.CountAsync(v => matchIds.Contains(v.MatchId) && v.VotedPlayerId == playerId);
        var votiPartite = await _context.MatchVotes.Where(v => matchIds.Contains(v.MatchId)).ToListAsync();
        var partiteMvp = votiPartite
            .GroupBy(v => v.MatchId)
            .Count(g =>
            {
                var conteggi = g.GroupBy(v => v.VotedPlayerId).Select(x => new { x.Key, N = x.Count() }).ToList();
                var max = conteggi.Max(x => x.N);
                return conteggi.Any(x => x.Key == playerId && x.N == max);
            });
        var convocazioni = await _context.Convocations
            .Where(c => c.PlayerId == playerId && matchIds.Contains(c.MatchId))
            .ToListAsync();

        var dto = new PlayerStatsDto
        {
            PlayerId = playerId,
            NomeGiocatore = player.Nome,
            Soprannome = player.Soprannome,
            PartitePresente = attendances.Count(a => a.Presente),
            PartiteGiocate = attendances.Count(a => a.HaGiocato),
            TotaleMinutiGiocati = attendances.Sum(a => a.MinutiGiocati ?? 0),
            TotaleGoal = attendances.Sum(a => a.Goal ?? 0),
            TotaleAssist = attendances.Sum(a => a.Assist ?? 0),
            TotaleAutogoal = attendances.Sum(a => a.Autogoal ?? 0),
            TotaleAmmonizioni = attendances.Sum(a => a.Ammonizioni ?? 0),
            TotaleEspulsioni = attendances.Sum(a => a.Espulsioni ?? 0),
            TotaleGoalSubiti = attendances.Sum(a => a.GoalSubiti ?? 0),
            MediaGoalPartita = attendances.Count(a => a.HaGiocato) > 0
                ? Math.Round((double)attendances.Sum(a => a.Goal ?? 0) / attendances.Count(a => a.HaGiocato), 2) : 0,
            MediaAssistPartita = attendances.Count(a => a.HaGiocato) > 0
                ? Math.Round((double)attendances.Sum(a => a.Assist ?? 0) / attendances.Count(a => a.HaGiocato), 2) : 0,
            VotiMvp = votiRicevuti,
            PartiteMvp = partiteMvp,
        };
        return ConAffidabilita(dto, convocazioni);
    }

    /// <summary>Riempie i campi di affidabilita' a partire dalle convocazioni del giocatore.</summary>
    private static PlayerStatsDto ConAffidabilita(PlayerStatsDto dto, IEnumerable<Convocation> convocazioni)
    {
        var list = convocazioni.ToList();
        dto.ConvocazioniRicevute = list.Count;
        dto.ConvocazioniConfermate = list.Count(c => c.StatoRisposta == StatoRisposta.Confermato);
        dto.Forfait = list.Count(c => c.StatoRisposta == StatoRisposta.NonDisponibile);
        dto.SenzaRisposta = list.Count(c => c.StatoRisposta == StatoRisposta.InAttesa);
        dto.Affidabilita = list.Count == 0 ? null : (int)Math.Round(100.0 * dto.ConvocazioniConfermate / list.Count);
        var risposte = list.Where(c => c.DataRisposta != null).Select(c => (c.DataRisposta!.Value - c.DataConvocazione).TotalHours).ToList();
        dto.OreMedieRisposta = risposte.Count == 0 ? null : Math.Round(risposte.Average(), 1);
        return dto;
    }
}
