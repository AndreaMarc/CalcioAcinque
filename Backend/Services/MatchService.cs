using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Matches;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IMatchService
{
    Task<List<MatchDto>> GetAllByTeamAsync(int teamId, StatoPartita? stato = null);
    Task<MatchDetailDto> GetByIdAsync(int teamId, int matchId);
    Task<MatchDto> CreateAsync(int teamId, CreateMatchDto dto);
    Task<MatchDto> UpdateAsync(int teamId, int matchId, UpdateMatchDto dto);
    Task DeleteAsync(int teamId, int matchId);
    Task<MatchDto> UpdateStatoAsync(int teamId, int matchId, StatoPartita stato);
}

public class MatchService : IMatchService
{
    private readonly ApplicationDbContext _context;
    public MatchService(ApplicationDbContext context) { _context = context; }

    public async Task<List<MatchDto>> GetAllByTeamAsync(int teamId, StatoPartita? stato = null)
    {
        var query = _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances).Where(m => m.TeamId == teamId);
        if (stato.HasValue) query = query.Where(m => m.Stato == stato.Value);
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

        var match = new Match { TeamId = teamId, Data = dto.Data.Date, Ora = ora, Luogo = dto.Luogo, Titolo = dto.Titolo, NumeroGiornata = dto.NumeroGiornata, Note = dto.Note, Stato = StatoPartita.Programmata, CreatedAt = DateTime.UtcNow };
        _context.Matches.Add(match);
        await _context.SaveChangesAsync();
        return MapToDto(match);
    }

    public async Task<MatchDto> UpdateAsync(int teamId, int matchId, UpdateMatchDto dto)
    {
        var match = await _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);
        if (dto.Data.HasValue) match.Data = dto.Data.Value.Date;
        if (dto.Ora != null && TimeSpan.TryParse(dto.Ora, out var ora)) match.Ora = ora;
        if (dto.Luogo != null) match.Luogo = dto.Luogo;
        if (dto.Titolo != null) match.Titolo = dto.Titolo;
        if (dto.NumeroGiornata.HasValue) match.NumeroGiornata = dto.NumeroGiornata.Value;
        if (dto.Note != null) match.Note = dto.Note;
        await _context.SaveChangesAsync();
        return MapToDto(match);
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

    public async Task<MatchDto> UpdateStatoAsync(int teamId, int matchId, StatoPartita stato)
    {
        var match = await _context.Matches.Include(m => m.Convocations).Include(m => m.Attendances)
            .FirstOrDefaultAsync(m => m.Id == matchId && m.TeamId == teamId);
        if (match == null) throw new NotFoundException("Partita", matchId);
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
