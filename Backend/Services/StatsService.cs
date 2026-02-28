using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Stats;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IStatsService
{
    Task<TeamStatsDto> GetTeamStatsAsync(int teamId);
    Task<PlayerStatsDto> GetPlayerStatsAsync(int playerId, int teamId);
}

public class StatsService : IStatsService
{
    private readonly ApplicationDbContext _context;

    public StatsService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<TeamStatsDto> GetTeamStatsAsync(int teamId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Squadra", teamId);

        // Partite concluse del team
        var matchIds = await _context.Matches
            .Where(m => m.TeamId == teamId && m.Stato == StatoPartita.Conclusa)
            .OrderBy(m => m.Data)
            .Select(m => new { m.Id, m.NumeroGiornata, m.Data })
            .ToListAsync();

        var allAttendances = await _context.MatchAttendances
            .Include(a => a.Player)
            .Where(a => matchIds.Select(m => m.Id).Contains(a.MatchId))
            .ToListAsync();

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
            })
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
            TotalePartite = matchIds.Count,
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

    public async Task<PlayerStatsDto> GetPlayerStatsAsync(int playerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var attendances = await _context.MatchAttendances
            .Include(a => a.Match)
            .Where(a => a.PlayerId == playerId && a.Match.Stato == StatoPartita.Conclusa)
            .ToListAsync();

        return new PlayerStatsDto
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
        };
    }
}
