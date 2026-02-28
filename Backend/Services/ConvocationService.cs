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
}

public class ConvocationService : IConvocationService
{
    private readonly ApplicationDbContext _context;
    public ConvocationService(ApplicationDbContext context) { _context = context; }

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

        foreach (var playerId in dto.PlayerIds)
        {
            var existing = await _context.Convocations.FirstOrDefaultAsync(c => c.MatchId == matchId && c.PlayerId == playerId);
            if (existing != null) continue;
            var player = await _context.Players.FindAsync(playerId);
            if (player == null) continue;

            _context.Convocations.Add(new Convocation { MatchId = matchId, PlayerId = playerId, StatoRisposta = StatoRisposta.InAttesa, DataConvocazione = DateTime.UtcNow, NotificaInviata = true });
            _context.MatchAttendances.Add(new MatchAttendance { MatchId = matchId, PlayerId = playerId, Convocato = true });
        }

        if (match.Stato == StatoPartita.Programmata) match.Stato = StatoPartita.ConvocazioniInviate;
        await _context.SaveChangesAsync();
        return await GetByMatchAsync(matchId, teamId);
    }

    public async Task<ConvocationDto> RespondAsync(int convocationId, int playerId, RespondConvocationDto dto)
    {
        var convocation = await _context.Convocations.Include(c => c.Player).Include(c => c.Match)
            .FirstOrDefaultAsync(c => c.Id == convocationId);
        if (convocation == null) throw new NotFoundException("Convocazione", convocationId);
        if (convocation.PlayerId != playerId) throw new UnauthorizedException("Non puoi rispondere alla convocazione di un altro giocatore");
        if (!Enum.TryParse<StatoRisposta>(dto.Risposta, true, out var stato) || stato == StatoRisposta.InAttesa)
            throw new BadRequestException("Risposta non valida. Usare 'Confermato' o 'NonDisponibile'");

        convocation.StatoRisposta = stato;
        convocation.DataRisposta = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return MapToDto(convocation);
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

    private static ConvocationDto MapToDto(Convocation c) => new()
    {
        Id = c.Id, MatchId = c.MatchId, PlayerId = c.PlayerId, NomeGiocatore = c.Player.Nome,
        Soprannome = c.Player.Soprannome, StatoRisposta = c.StatoRisposta.ToString(),
        DataConvocazione = c.DataConvocazione, DataRisposta = c.DataRisposta,
        DataPartita = c.Match?.Data, OraPartita = c.Match?.Ora.ToString(@"hh\:mm"),
        LuogoPartita = c.Match?.Luogo, NumeroGiornata = c.Match?.NumeroGiornata
    };
}
