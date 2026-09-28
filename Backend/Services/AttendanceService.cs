using CalcioAcinque.Backend.Models;
using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Attendance;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IAttendanceService
{
    Task<List<MatchAttendanceDto>> GetByMatchAsync(int matchId, int teamId);
    Task<MatchAttendanceDto> UpdateAttendanceAsync(int matchId, int playerId, UpdateAttendanceDto dto, int adminPlayerId, int teamId);
}

public class AttendanceService : IAttendanceService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<AttendanceService> _logger;

    public AttendanceService(ApplicationDbContext context, ILogger<AttendanceService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<List<MatchAttendanceDto>> GetByMatchAsync(int matchId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var attendances = await _context.MatchAttendances.Include(a => a.Player).ThenInclude(p => p.Team)
            .Where(a => a.MatchId == matchId).OrderBy(a => a.Player.Nome).ToListAsync();
        return attendances.Select(MapToDto).ToList();
    }

    public async Task<MatchAttendanceDto> UpdateAttendanceAsync(int matchId, int playerId, UpdateAttendanceDto dto, int adminPlayerId, int teamId)
    {
        var match = await _context.Matches.FindAsync(matchId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (match.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        if (match.Stato == StatoPartita.Conclusa)
            throw new BusinessException("Non puoi modificare presenze di una partita conclusa");

        var attendance = await _context.MatchAttendances.Include(a => a.Player).ThenInclude(p => p.Team)
            .FirstOrDefaultAsync(a => a.MatchId == matchId && a.PlayerId == playerId);
        if (attendance == null) throw new NotFoundException("Presenza", $"{matchId}/{playerId}");

        var player = attendance.Player;
        var avevaGiocato = attendance.HaGiocato;
        var team = await _context.Teams.FindAsync(match.TeamId);
        // Per il singolo: puo' usare i gettoni anche se la squadra no (o viceversa)
        var useGettoni = team == null || GettoniGiocatore.Attivi(player, team);

        // Gestione campo "Presente" con consumo automatico gettone
        // Congelato sulla transazione: l'admin puo' uscire dalla rosa, il
        // movimento sui gettoni deve restare leggibile
        var adminNome = !useGettoni && !attendance.GettoneConsumato ? "" : await _context.Players
            .Where(p => p.Id == adminPlayerId)
            .Select(p => p.Nome)
            .FirstOrDefaultAsync() ?? "";

        if (dto.Presente.HasValue)
        {
            if (dto.Presente.Value && !attendance.Presente)
            {
                attendance.Presente = true;

                if (useGettoni)
                {
                    if (player.GettoniRimanenti > 0)
                    {
                        player.GettoniConsumati += 1;
                        attendance.GettoneConsumato = true;
                        _context.TokenTransactions.Add(new TokenTransaction
                        {
                            PlayerId = playerId, MatchId = matchId, Tipo = TipoTransazione.ConsumoAutomatico,
                            Motivazione = $"Consumo automatico per presenza alla giornata {match.NumeroGiornata}",
                            Quantita = -1, AdminId = adminPlayerId, AdminNome = adminNome,
                            Timestamp = DateTime.UtcNow
                        });
                    }
                    else
                    {
                        attendance.GettoneConsumato = false;
                        _logger.LogWarning("Giocatore {PlayerId} presente senza gettoni alla partita {MatchId}", playerId, matchId);
                        _context.TokenTransactions.Add(new TokenTransaction
                        {
                            PlayerId = playerId, MatchId = matchId, Tipo = TipoTransazione.ConsumoAutomatico,
                            Motivazione = $"Presenza alla giornata {match.NumeroGiornata} - GETTONI ESAURITI",
                            Quantita = 0, AdminId = adminPlayerId, AdminNome = adminNome,
                            Timestamp = DateTime.UtcNow
                        });
                    }
                }
            }
            else if (!dto.Presente.Value && attendance.Presente)
            {
                // Il gettone speso si restituisce comunque, anche se nel frattempo
                // i gettoni sono stati spenti per lui
                if (attendance.GettoneConsumato)
                {
                    player.GettoniConsumati -= 1;
                    attendance.GettoneConsumato = false;
                    _context.TokenTransactions.Add(new TokenTransaction
                    {
                        PlayerId = playerId, MatchId = matchId, Tipo = TipoTransazione.Override,
                        Motivazione = "Annullamento presenza - gettone restituito",
                        Quantita = 1, AdminId = adminPlayerId, AdminNome = adminNome,
                        Timestamp = DateTime.UtcNow
                    });
                }
                attendance.Presente = false;
                attendance.HaGiocato = false;
            }
        }

        // Gestione campo "HaGiocato"
        if (dto.HaGiocato.HasValue)
        {
            if (dto.HaGiocato.Value && !attendance.Presente)
                throw new BusinessException("Un giocatore deve essere presente per poter giocare");
            attendance.HaGiocato = dto.HaGiocato.Value;
        }

        // Chi paga a partita riceve l'addebito quando l'admin lo segna in campo,
        // e lo perde se viene tolto (finche' non l'ha pagato o dichiarato)
        if (attendance.HaGiocato && !avevaGiocato && team != null)
            await AddebitiPartita.CreaAsync(_context, match, team, new[] { player });
        else if (!attendance.HaGiocato && avevaGiocato)
            await AddebitiPartita.TogliAsync(_context, matchId, playerId);

        // Gestione statistiche facoltative
        if (dto.MinutiGiocati.HasValue) attendance.MinutiGiocati = dto.MinutiGiocati.Value;
        if (dto.Goal.HasValue) attendance.Goal = dto.Goal.Value;
        if (dto.Assist.HasValue) attendance.Assist = dto.Assist.Value;
        if (dto.Autogoal.HasValue) attendance.Autogoal = dto.Autogoal.Value;
        if (dto.Ammonizioni.HasValue) attendance.Ammonizioni = dto.Ammonizioni.Value;
        if (dto.Espulsioni.HasValue) attendance.Espulsioni = dto.Espulsioni.Value;
        if (dto.GoalSubiti.HasValue) attendance.GoalSubiti = dto.GoalSubiti.Value;

        await _context.SaveChangesAsync();
        return MapToDto(attendance);
    }

    private static MatchAttendanceDto MapToDto(MatchAttendance a) => new()
    {
        Id = a.Id, MatchId = a.MatchId, PlayerId = a.PlayerId, NomeGiocatore = a.Player.Nome,
        Soprannome = a.Player.Soprannome, Convocato = a.Convocato, Presente = a.Presente,
        HaGiocato = a.HaGiocato, GettoneConsumato = a.GettoneConsumato, GettoniRimanenti = a.Player.GettoniRimanenti,
        UsaGettoni = GettoniGiocatore.Attivi(a.Player, a.Player.Team),
        MinutiGiocati = a.MinutiGiocati, Goal = a.Goal, Assist = a.Assist,
        Autogoal = a.Autogoal, Ammonizioni = a.Ammonizioni, Espulsioni = a.Espulsioni, GoalSubiti = a.GoalSubiti
    };
}
