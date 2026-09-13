using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Availability;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IAvailabilityService
{
    Task<AvailabilityDto> SetAvailabilityAsync(int matchId, int playerId, SetAvailabilityDto dto, int teamId);
    Task<MatchAvailabilitySummaryDto> GetByMatchAsync(int matchId, int? currentPlayerId = null, int? teamId = null);
    Task<MatchAvailabilitySummaryDto?> GetNextMatchAvailabilityAsync(int teamId, int playerId);
}

public class AvailabilityService : IAvailabilityService
{
    private readonly ApplicationDbContext _context;
    public AvailabilityService(ApplicationDbContext context) { _context = context; }

    public async Task<AvailabilityDto> SetAvailabilityAsync(int matchId, int playerId, SetAvailabilityDto dto, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        if (match.Stato == StatoPartita.Conclusa) throw new BusinessException("Non puoi dichiarare disponibilità per una partita conclusa");

        var existing = await _context.PlayerAvailabilities
            .Include(a => a.Player)
            .FirstOrDefaultAsync(a => a.MatchId == matchId && a.PlayerId == playerId);

        if (existing != null)
        {
            existing.Disponibile = dto.Disponibile;
            existing.Note = dto.Note;
            existing.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            var player = await _context.Players.FindAsync(playerId);
            if (player == null) throw new NotFoundException("Giocatore", playerId);

            existing = new PlayerAvailability
            {
                MatchId = matchId,
                PlayerId = playerId,
                Disponibile = dto.Disponibile,
                Note = dto.Note,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.PlayerAvailabilities.Add(existing);
        }

        await _context.SaveChangesAsync();

        // Ricarica per avere la nav property Player
        await _context.Entry(existing).Reference(a => a.Player).LoadAsync();
        return MapToDto(existing);
    }

    public async Task<MatchAvailabilitySummaryDto> GetByMatchAsync(int matchId, int? currentPlayerId = null, int? teamId = null)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (teamId.HasValue && match.TeamId != teamId.Value) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var availabilities = await _context.PlayerAvailabilities
            .Include(a => a.Player)
            .Where(a => a.MatchId == matchId)
            .OrderBy(a => a.Player.Nome)
            .ToListAsync();

        string? miaDisp = null;
        if (currentPlayerId.HasValue)
        {
            var mia = availabilities.FirstOrDefault(a => a.PlayerId == currentPlayerId.Value);
            miaDisp = mia != null ? (mia.Disponibile ? "disponibile" : "nonDisponibile") : null;
        }

        // La rosa che gioca: cosi' "senza risposta" = rosa - disponibili - non disponibili
        var rosa = await _context.Players.CountAsync(p => p.TeamId == match.TeamId && p.Gioca);

        return new MatchAvailabilitySummaryDto
        {
            MatchId = match.Id,
            NumeroGiornata = match.NumeroGiornata,
            DataPartita = match.Data,
            OraPartita = match.Ora.ToString(@"hh\:mm"),
            // I numeri sono dei giocatori: lo staff (Gioca = false) sta nel dettaglio ma non nei conteggi
            Disponibili = availabilities.Count(a => a.Disponibile && a.Player.Gioca),
            NonDisponibili = availabilities.Count(a => !a.Disponibile && a.Player.Gioca),
            Totale = rosa,
            Dettaglio = availabilities.Select(MapToDto).ToList(),
            MiaDisponibilita = miaDisp
        };
    }

    public async Task<MatchAvailabilitySummaryDto?> GetNextMatchAvailabilityAsync(int teamId, int playerId)
    {
        var nextMatch = await _context.Matches
            .Where(m => m.TeamId == teamId && m.Stato != StatoPartita.Conclusa)
            .OrderBy(m => m.Data)
            .FirstOrDefaultAsync();

        if (nextMatch == null) return null;
        return await GetByMatchAsync(nextMatch.Id, playerId);
    }

    private static AvailabilityDto MapToDto(PlayerAvailability a) => new()
    {
        Id = a.Id, MatchId = a.MatchId, PlayerId = a.PlayerId,
        NomeGiocatore = a.Player.Nome, Soprannome = a.Player.Soprannome,
        Gioca = a.Player.Gioca, Ruolo = a.Player.Ruolo.ToString(),
        Disponibile = a.Disponibile, Note = a.Note, UpdatedAt = a.UpdatedAt
    };
}
