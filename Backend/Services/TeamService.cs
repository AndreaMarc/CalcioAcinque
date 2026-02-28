using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Teams;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;

namespace CalcioAcinque.Backend.Services;

public interface ITeamService
{
    Task<TeamDto> GetByIdAsync(int teamId);
    Task<TeamDto> CreateAsync(CreateTeamDto dto);
    Task<TeamDto> UpdateAsync(int teamId, UpdateTeamDto dto);
}

public class TeamService : ITeamService
{
    private readonly ApplicationDbContext _context;

    public TeamService(ApplicationDbContext context) { _context = context; }

    public async Task<TeamDto> GetByIdAsync(int teamId)
    {
        var team = await _context.Teams.Include(t => t.Players).FirstOrDefaultAsync(t => t.Id == teamId);
        if (team == null) throw new NotFoundException("Team", teamId);
        return MapToDto(team);
    }

    public async Task<TeamDto> CreateAsync(CreateTeamDto dto)
    {
        var team = new Team { Nome = dto.Nome, PartitePerStagione = dto.PartitePerStagione, GettoniPerGiocatore = dto.GettoniPerGiocatore, UseGettoni = dto.UseGettoni, CreatedAt = DateTime.UtcNow };
        _context.Teams.Add(team);
        await _context.SaveChangesAsync();
        return MapToDto(team);
    }

    public async Task<TeamDto> UpdateAsync(int teamId, UpdateTeamDto dto)
    {
        var team = await _context.Teams.Include(t => t.Players).FirstOrDefaultAsync(t => t.Id == teamId);
        if (team == null) throw new NotFoundException("Team", teamId);
        if (dto.Nome != null) team.Nome = dto.Nome;
        if (dto.PartitePerStagione.HasValue) team.PartitePerStagione = dto.PartitePerStagione.Value;
        if (dto.GettoniPerGiocatore.HasValue) team.GettoniPerGiocatore = dto.GettoniPerGiocatore.Value;
        if (dto.UseGettoni.HasValue) team.UseGettoni = dto.UseGettoni.Value;
        await _context.SaveChangesAsync();
        return MapToDto(team);
    }

    private static TeamDto MapToDto(Team team) => new()
    {
        Id = team.Id, Nome = team.Nome, PartitePerStagione = team.PartitePerStagione,
        GettoniPerGiocatore = team.GettoniPerGiocatore, UseGettoni = team.UseGettoni,
        TotaleGiocatori = team.Players?.Count ?? 0, CreatedAt = team.CreatedAt
    };
}
