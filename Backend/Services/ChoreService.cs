using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Chores;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IChoreService
{
    Task<List<TeamChoreDto>> GetTeamChoresAsync(int teamId);
    Task<TeamChoreDto> CreateAsync(int teamId, UpsertChoreDto dto);
    Task<TeamChoreDto> UpdateAsync(int choreId, int teamId, UpsertChoreDto dto);
    Task DeleteAsync(int choreId, int teamId);
    Task<List<MatchChoreDto>> GetMatchChoresAsync(int matchId, int teamId);
    Task<List<MatchChoreDto>> AssignAsync(int matchId, int teamId);
    Task<List<MatchChoreDto>> SetAsync(int matchId, int choreId, int? playerId, int teamId);
}

/// <summary>
/// Turni di squadra (casacche, palloni, maglie): la rotazione automatica sceglie,
/// tra i convocati che hanno confermato, chi non lo fa da piu' tempo.
/// </summary>
public class ChoreService : IChoreService
{
    private readonly ApplicationDbContext _context;

    public ChoreService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<TeamChoreDto>> GetTeamChoresAsync(int teamId)
    {
        var chores = await _context.TeamChores
            .Where(c => c.TeamId == teamId)
            .OrderBy(c => c.Ordine).ThenBy(c => c.Id)
            .ToListAsync();
        return chores.Select(MapChore).ToList();
    }

    public async Task<TeamChoreDto> CreateAsync(int teamId, UpsertChoreDto dto)
    {
        _ = await _context.Teams.FindAsync(teamId) ?? throw new NotFoundException("Team", teamId);
        var count = await _context.TeamChores.CountAsync(c => c.TeamId == teamId);
        if (count >= 10) throw new BusinessException("Massimo 10 turni per squadra");

        var chore = new TeamChore
        {
            TeamId = teamId,
            Nome = dto.Nome.Trim(),
            Attivo = dto.Attivo ?? true,
            Ordine = count,
            CreatedAt = DateTime.UtcNow
        };
        _context.TeamChores.Add(chore);
        await _context.SaveChangesAsync();
        return MapChore(chore);
    }

    public async Task<TeamChoreDto> UpdateAsync(int choreId, int teamId, UpsertChoreDto dto)
    {
        var chore = await _context.TeamChores.FirstOrDefaultAsync(c => c.Id == choreId && c.TeamId == teamId)
            ?? throw new NotFoundException("Turno", choreId);
        chore.Nome = dto.Nome.Trim();
        if (dto.Attivo.HasValue) chore.Attivo = dto.Attivo.Value;
        await _context.SaveChangesAsync();
        return MapChore(chore);
    }

    public async Task DeleteAsync(int choreId, int teamId)
    {
        var chore = await _context.TeamChores.FirstOrDefaultAsync(c => c.Id == choreId && c.TeamId == teamId)
            ?? throw new NotFoundException("Turno", choreId);
        _context.TeamChores.Remove(chore);
        await _context.SaveChangesAsync();
    }

    public async Task<List<MatchChoreDto>> GetMatchChoresAsync(int matchId, int teamId)
    {
        await LoadMatchAsync(matchId, teamId);
        return await BuildAsync(matchId, teamId);
    }

    public async Task<List<MatchChoreDto>> AssignAsync(int matchId, int teamId)
    {
        var match = await LoadMatchAsync(matchId, teamId);
        var chores = await _context.TeamChores
            .Where(c => c.TeamId == teamId && c.Attivo)
            .OrderBy(c => c.Ordine).ThenBy(c => c.Id)
            .ToListAsync();
        if (chores.Count == 0)
            throw new BusinessException("Nessun turno configurato: aggiungili dalle impostazioni della squadra");

        var convocazioni = await _context.Convocations
            .Include(c => c.Player)
            .Where(c => c.MatchId == matchId)
            .ToListAsync();
        if (convocazioni.Count == 0)
            throw new BusinessException("Prima convoca i giocatori: i turni girano tra i convocati");

        // Chi ha confermato ha la precedenza; se nessuno ha ancora risposto si usa tutta la lista
        var pool = convocazioni.Where(c => c.StatoRisposta == StatoRisposta.Confermato).Select(c => c.Player).ToList();
        if (pool.Count == 0)
            pool = convocazioni.Where(c => c.StatoRisposta != StatoRisposta.NonDisponibile).Select(c => c.Player).ToList();
        if (pool.Count == 0)
            throw new BusinessException("Nessun convocato disponibile a cui assegnare i turni");

        var poolIds = pool.Select(p => p.Id).ToList();

        // Ultimo turno fatto da ciascuno (in qualunque partita precedente) e quante volte
        var storico = await _context.MatchChoreAssignments
            .Include(a => a.Match)
            .Where(a => a.PlayerId != null && poolIds.Contains(a.PlayerId.Value) && a.MatchId != matchId)
            .ToListAsync();
        var ultimo = poolIds.ToDictionary(id => id, id => storico
            .Where(a => a.PlayerId == id)
            .Select(a => a.Match.Data)
            .DefaultIfEmpty(DateTime.MinValue)
            .Max());
        var quante = poolIds.ToDictionary(id => id, id => storico.Count(a => a.PlayerId == id));

        var esistenti = await _context.MatchChoreAssignments
            .Where(a => a.MatchId == matchId)
            .ToListAsync();
        var occupati = esistenti.Where(a => a.PlayerId != null).Select(a => a.PlayerId!.Value).ToHashSet();

        foreach (var chore in chores)
        {
            var assignment = esistenti.FirstOrDefault(a => a.ChoreId == chore.Id);
            if (assignment?.PlayerId != null) continue;

            // Chi non lo fa da piu' tempo, poi chi ne ha fatti meno; un turno a testa se si puo'
            var scelto = pool
                .Where(p => !occupati.Contains(p.Id))
                .OrderBy(p => ultimo[p.Id])
                .ThenBy(p => quante[p.Id])
                .ThenBy(p => p.Nome)
                .FirstOrDefault()
                ?? pool.OrderBy(p => ultimo[p.Id]).ThenBy(p => quante[p.Id]).ThenBy(p => p.Nome).First();

            if (assignment == null)
            {
                _context.MatchChoreAssignments.Add(new MatchChoreAssignment
                {
                    MatchId = match.Id,
                    ChoreId = chore.Id,
                    PlayerId = scelto.Id,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                assignment.PlayerId = scelto.Id;
            }
            occupati.Add(scelto.Id);
        }

        await _context.SaveChangesAsync();
        return await BuildAsync(matchId, teamId);
    }

    public async Task<List<MatchChoreDto>> SetAsync(int matchId, int choreId, int? playerId, int teamId)
    {
        var match = await LoadMatchAsync(matchId, teamId);
        var chore = await _context.TeamChores.FirstOrDefaultAsync(c => c.Id == choreId && c.TeamId == teamId)
            ?? throw new NotFoundException("Turno", choreId);
        if (playerId.HasValue && !await _context.Players.AnyAsync(p => p.Id == playerId.Value && p.TeamId == teamId))
            throw new NotFoundException("Giocatore", playerId.Value);

        var assignment = await _context.MatchChoreAssignments
            .FirstOrDefaultAsync(a => a.MatchId == matchId && a.ChoreId == choreId);
        if (assignment == null)
        {
            _context.MatchChoreAssignments.Add(new MatchChoreAssignment
            {
                MatchId = match.Id,
                ChoreId = chore.Id,
                PlayerId = playerId,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            assignment.PlayerId = playerId;
        }
        await _context.SaveChangesAsync();
        return await BuildAsync(matchId, teamId);
    }

    private async Task<Match> LoadMatchAsync(int matchId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId) ?? throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        return match;
    }

    private async Task<List<MatchChoreDto>> BuildAsync(int matchId, int teamId)
    {
        var chores = await _context.TeamChores
            .Where(c => c.TeamId == teamId && c.Attivo)
            .OrderBy(c => c.Ordine).ThenBy(c => c.Id)
            .ToListAsync();
        var assignments = await _context.MatchChoreAssignments
            .Include(a => a.Player)
            .Where(a => a.MatchId == matchId)
            .ToListAsync();

        return chores.Select(c =>
        {
            var a = assignments.FirstOrDefault(x => x.ChoreId == c.Id);
            return new MatchChoreDto
            {
                ChoreId = c.Id,
                Nome = c.Nome,
                PlayerId = a?.PlayerId,
                NomeGiocatore = a?.Player?.Nome,
                Soprannome = a?.Player?.Soprannome
            };
        }).ToList();
    }

    private static TeamChoreDto MapChore(TeamChore c) => new()
    {
        Id = c.Id, Nome = c.Nome, Attivo = c.Attivo, Ordine = c.Ordine
    };
}
