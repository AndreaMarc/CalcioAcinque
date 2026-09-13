using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Mvp;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IMatchVoteService
{
    Task<MatchMvpDto> GetAsync(int matchId, int teamId, int voterPlayerId);
    Task<MatchMvpDto> VoteAsync(int matchId, int teamId, int voterPlayerId, int votedPlayerId);
    Task<MatchMvpDto> RemoveVoteAsync(int matchId, int teamId, int voterPlayerId);
}

/// <summary>Il migliore in campo: un voto a testa, tra i presenti, a partita conclusa.</summary>
public class MatchVoteService : IMatchVoteService
{
    private readonly ApplicationDbContext _context;

    public MatchVoteService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<MatchMvpDto> GetAsync(int matchId, int teamId, int voterPlayerId)
    {
        var match = await LoadMatchAsync(matchId, teamId);
        return await BuildAsync(match, voterPlayerId);
    }

    public async Task<MatchMvpDto> VoteAsync(int matchId, int teamId, int voterPlayerId, int votedPlayerId)
    {
        var match = await LoadMatchAsync(matchId, teamId);
        if (match.Stato != StatoPartita.Conclusa)
            throw new BusinessException("Si vota il migliore in campo a partita conclusa");
        if (votedPlayerId == voterPlayerId)
            throw new BusinessException("Non puoi votare te stesso");

        var presente = await _context.MatchAttendances
            .AnyAsync(a => a.MatchId == matchId && a.PlayerId == votedPlayerId && a.Presente);
        if (!presente)
            throw new BusinessException("Si puo' votare solo chi era presente alla partita");

        var vote = await _context.MatchVotes
            .FirstOrDefaultAsync(v => v.MatchId == matchId && v.VoterPlayerId == voterPlayerId);
        if (vote == null)
        {
            _context.MatchVotes.Add(new MatchVote
            {
                MatchId = matchId,
                VoterPlayerId = voterPlayerId,
                VotedPlayerId = votedPlayerId,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            vote.VotedPlayerId = votedPlayerId;
            vote.CreatedAt = DateTime.UtcNow;
        }
        await _context.SaveChangesAsync();
        return await BuildAsync(match, voterPlayerId);
    }

    public async Task<MatchMvpDto> RemoveVoteAsync(int matchId, int teamId, int voterPlayerId)
    {
        var match = await LoadMatchAsync(matchId, teamId);
        var vote = await _context.MatchVotes
            .FirstOrDefaultAsync(v => v.MatchId == matchId && v.VoterPlayerId == voterPlayerId);
        if (vote != null)
        {
            _context.MatchVotes.Remove(vote);
            await _context.SaveChangesAsync();
        }
        return await BuildAsync(match, voterPlayerId);
    }

    private async Task<Match> LoadMatchAsync(int matchId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId) ?? throw new NotFoundException("Partita", matchId);
        // Le route /api/matches/{id}/... non passano dal middleware del teamId
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        return match;
    }

    private async Task<MatchMvpDto> BuildAsync(Match match, int voterPlayerId)
    {
        var presenti = await _context.MatchAttendances
            .Include(a => a.Player)
            .Where(a => a.MatchId == match.Id && a.Presente)
            .OrderBy(a => a.Player.Nome)
            .ToListAsync();

        var voti = await _context.MatchVotes
            .Include(v => v.Voted)
            .Where(v => v.MatchId == match.Id)
            .ToListAsync();

        return new MatchMvpDto
        {
            MatchId = match.Id,
            Aperto = match.Stato == StatoPartita.Conclusa,
            MioVotoPlayerId = voti.FirstOrDefault(v => v.VoterPlayerId == voterPlayerId)?.VotedPlayerId,
            TotaleVoti = voti.Count,
            Classifica = voti
                .GroupBy(v => v.VotedPlayerId)
                .Select(g => new MvpVoteCountDto
                {
                    PlayerId = g.Key,
                    Nome = g.First().Voted.Nome,
                    Soprannome = g.First().Voted.Soprannome,
                    Voti = g.Count()
                })
                .OrderByDescending(c => c.Voti)
                .ThenBy(c => c.Nome)
                .ToList(),
            Candidati = presenti.Select(a => new MvpCandidateDto
            {
                PlayerId = a.PlayerId,
                Nome = a.Player.Nome,
                Soprannome = a.Player.Soprannome,
                NumeroMaglia = a.Player.NumeroMaglia
            }).ToList()
        };
    }
}
