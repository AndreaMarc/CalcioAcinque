using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IPlayerService
{
    Task<List<PlayerDto>> GetAllByTeamAsync(int teamId);
    Task<PlayerDetailDto> GetByIdAsync(int teamId, int playerId);
    Task<PlayerDto> CreateAsync(int teamId, CreatePlayerDto dto);
    Task<PlayerDto> UpdateAsync(int teamId, int playerId, UpdatePlayerDto dto);
    Task DeleteAsync(int teamId, int playerId);
    Task ResetPasswordAsync(int teamId, int playerId, string newPassword);
    Task<PlayerDto> UpdateMyProfileAsync(int playerId, int teamId, UpdateMyProfileDto dto);
}

public class PlayerService : IPlayerService
{
    private readonly ApplicationDbContext _context;
    public PlayerService(ApplicationDbContext context) { _context = context; }

    public async Task<List<PlayerDto>> GetAllByTeamAsync(int teamId)
    {
        var players = await _context.Players.Where(p => p.TeamId == teamId).OrderBy(p => p.Nome).ToListAsync();
        return players.Select(MapToDto).ToList();
    }

    public async Task<PlayerDetailDto> GetByIdAsync(int teamId, int playerId)
    {
        var player = await _context.Players.Include(p => p.User).Include(p => p.Attendances)
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        return new PlayerDetailDto
        {
            Id = player.Id, TeamId = player.TeamId, UserId = player.UserId, Nome = player.Nome,
            Soprannome = player.Soprannome, Telefono = player.Telefono, Ruolo = player.Ruolo.ToString(),
            GettoniTotali = player.GettoniTotali, GettoniConsumati = player.GettoniConsumati,
            GettoniRimanenti = player.GettoniRimanenti, IscrizionePagata = player.IscrizionePagata,
            TesseramentoPagato = player.TesseramentoPagato, CreatedAt = player.CreatedAt,
            Email = player.User.Email,
            PartiteConvocato = player.Attendances.Count(a => a.Convocato),
            PartitePresente = player.Attendances.Count(a => a.Presente),
            PartiteGiocate = player.Attendances.Count(a => a.HaGiocato)
        };
    }

    public async Task<PlayerDto> CreateAsync(int teamId, CreatePlayerDto dto)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Team", teamId);

        var existingUser = await _context.Users
            .Include(u => u.Players)
            .FirstOrDefaultAsync(u => u.Email == dto.Email);

        User user;
        if (existingUser != null)
        {
            // Utente esiste già — verifica che non sia già in questo team
            if (existingUser.Players.Any(p => p.TeamId == teamId))
                throw new ConflictException("Questo utente e' gia' nel team");
            user = existingUser;
        }
        else
        {
            user = new User { Email = dto.Email, PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password), IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
        }

        var ruolo = Enum.TryParse<UserRole>(dto.Ruolo, true, out var parsed) ? parsed : UserRole.User;
        var player = new Player { TeamId = teamId, UserId = user.Id, Nome = dto.Nome, Soprannome = dto.Soprannome, Telefono = dto.Telefono, Ruolo = ruolo, GettoniTotali = team.GettoniPerGiocatore, GettoniConsumati = 0, CreatedAt = DateTime.UtcNow };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();
        return MapToDto(player);
    }

    public async Task<PlayerDto> UpdateAsync(int teamId, int playerId, UpdatePlayerDto dto)
    {
        var player = await _context.Players.FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (dto.Nome != null) player.Nome = dto.Nome;
        if (dto.Soprannome != null) player.Soprannome = dto.Soprannome;
        if (dto.Telefono != null) player.Telefono = dto.Telefono;
        if (dto.IscrizionePagata.HasValue) player.IscrizionePagata = dto.IscrizionePagata.Value;
        if (dto.TesseramentoPagato.HasValue) player.TesseramentoPagato = dto.TesseramentoPagato.Value;
        if (dto.Ruolo != null && Enum.TryParse<UserRole>(dto.Ruolo, true, out var parsedRole)) player.Ruolo = parsedRole;
        await _context.SaveChangesAsync();
        return MapToDto(player);
    }

    public async Task DeleteAsync(int teamId, int playerId)
    {
        var player = await _context.Players
            .Include(p => p.User)
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        // Controlla che non sia l'ultimo admin
        if (player.Ruolo == UserRole.Admin)
        {
            var adminCount = await _context.Players.CountAsync(p => p.TeamId == teamId && p.Ruolo == UserRole.Admin);
            if (adminCount <= 1)
                throw new BusinessException("Non puoi eliminare l'ultimo admin del team");
        }

        var userId = player.UserId;

        // Rimuovi player (cascade elimina convocations, attendances, etc.)
        _context.Players.Remove(player);
        await _context.SaveChangesAsync();

        // Elimina l'utente SOLO se non ha più player in nessun team
        var hasOtherPlayers = await _context.Players.AnyAsync(p => p.UserId == userId);
        if (!hasOtherPlayers)
        {
            var refreshTokens = await _context.RefreshTokens.Where(rt => rt.UserId == userId).ToListAsync();
            _context.RefreshTokens.RemoveRange(refreshTokens);

            var user = await _context.Users.FindAsync(userId);
            if (user != null) _context.Users.Remove(user);
            await _context.SaveChangesAsync();
        }
    }

    public async Task ResetPasswordAsync(int teamId, int playerId, string newPassword)
    {
        var player = await _context.Players
            .Include(p => p.User)
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        player.User.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        player.User.UpdatedAt = DateTime.UtcNow;

        // Invalida tutti i refresh tokens esistenti
        var refreshTokens = await _context.RefreshTokens.Where(rt => rt.UserId == player.UserId).ToListAsync();
        _context.RefreshTokens.RemoveRange(refreshTokens);

        await _context.SaveChangesAsync();
    }

    public async Task<PlayerDto> UpdateMyProfileAsync(int playerId, int teamId, UpdateMyProfileDto dto)
    {
        var player = await _context.Players.FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (dto.Nome != null) player.Nome = dto.Nome;
        if (dto.Soprannome != null) player.Soprannome = dto.Soprannome;
        if (dto.Telefono != null) player.Telefono = dto.Telefono;
        await _context.SaveChangesAsync();
        return MapToDto(player);
    }

    private static PlayerDto MapToDto(Player p) => new()
    {
        Id = p.Id, TeamId = p.TeamId, UserId = p.UserId, Nome = p.Nome, Soprannome = p.Soprannome,
        Telefono = p.Telefono, Ruolo = p.Ruolo.ToString(), GettoniTotali = p.GettoniTotali,
        GettoniConsumati = p.GettoniConsumati, GettoniRimanenti = p.GettoniRimanenti,
        IscrizionePagata = p.IscrizionePagata, TesseramentoPagato = p.TesseramentoPagato, CreatedAt = p.CreatedAt
    };
}
