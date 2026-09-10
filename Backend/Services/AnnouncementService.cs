using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Announcements;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IAnnouncementService
{
    Task<List<AnnouncementDto>> GetAllByTeamAsync(int teamId, int currentPlayerId);
    Task<AnnouncementDetailDto> GetByIdAsync(int teamId, int announcementId, int currentPlayerId);
    Task<AnnouncementDto> CreateAsync(int teamId, int authorId, CreateAnnouncementDto dto);
    Task DeleteAsync(int teamId, int announcementId);
    Task<bool> AcknowledgeAsync(int teamId, int announcementId, int playerId);
}

public class AnnouncementService : IAnnouncementService
{
    private readonly ApplicationDbContext _context;
    private readonly INotificationService _notifications;

    public AnnouncementService(ApplicationDbContext context, INotificationService notifications)
    {
        _context = context;
        _notifications = notifications;
    }

    public async Task<List<AnnouncementDto>> GetAllByTeamAsync(int teamId, int currentPlayerId)
    {
        var totalPlayers = await _context.Players.CountAsync(p => p.TeamId == teamId);

        var announcements = await _context.Announcements
            .Include(a => a.Author)
            .Include(a => a.Reads)
            .Where(a => a.TeamId == teamId)
            .OrderByDescending(a => a.Importante)
            .ThenByDescending(a => a.CreatedAt)
            .ToListAsync();

        return announcements.Select(a => MapToDto(a, currentPlayerId, totalPlayers)).ToList();
    }

    public async Task<AnnouncementDetailDto> GetByIdAsync(int teamId, int announcementId, int currentPlayerId)
    {
        var totalPlayers = await _context.Players.CountAsync(p => p.TeamId == teamId);

        var announcement = await _context.Announcements
            .Include(a => a.Author)
            .Include(a => a.Reads).ThenInclude(r => r.Player)
            .FirstOrDefaultAsync(a => a.Id == announcementId && a.TeamId == teamId);

        if (announcement == null)
            throw new NotFoundException("Comunicazione", announcementId);

        return new AnnouncementDetailDto
        {
            Id = announcement.Id,
            TeamId = announcement.TeamId,
            AuthorId = announcement.AuthorId,
            AutoreNome = announcement.AutoreNome,
            AutoreSoprannome = announcement.AutoreSoprannome,
            Titolo = announcement.Titolo,
            Contenuto = announcement.Contenuto,
            Importante = announcement.Importante,
            CreatedAt = announcement.CreatedAt,
            TotalePresaVisione = announcement.Reads.Count,
            TotaleGiocatori = totalPlayers,
            HoPresaVisione = announcement.Reads.Any(r => r.PlayerId == currentPlayerId),
            PresaVisione = announcement.Reads
                .OrderBy(r => r.ReadAt)
                .Select(r => new AnnouncementReadDto
                {
                    PlayerId = r.PlayerId,
                    NomeGiocatore = r.Player.Nome,
                    Soprannome = r.Player.Soprannome,
                    ReadAt = r.ReadAt
                }).ToList()
        };
    }

    public async Task<AnnouncementDto> CreateAsync(int teamId, int authorId, CreateAnnouncementDto dto)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Team", teamId);

        var author = await _context.Players.FirstOrDefaultAsync(p => p.Id == authorId && p.TeamId == teamId);
        if (author == null) throw new NotFoundException("Giocatore", authorId);

        var announcement = new Announcement
        {
            TeamId = teamId,
            AuthorId = authorId,
            AutoreNome = author.Nome,
            AutoreSoprannome = author.Soprannome,
            Titolo = dto.Titolo,
            Contenuto = dto.Contenuto,
            Importante = dto.Importante,
            CreatedAt = DateTime.UtcNow
        };

        _context.Announcements.Add(announcement);
        await _context.SaveChangesAsync();

        // Reload with author
        await _context.Entry(announcement).Reference(a => a.Author).LoadAsync();

        var totalPlayers = await _context.Players.CountAsync(p => p.TeamId == teamId);

        // Tutti tranne chi lo ha scritto
        var destinatari = await _context.Players
            .Where(p => p.TeamId == teamId && p.Id != authorId)
            .Select(p => p.UserId)
            .ToListAsync();

        await _notifications.QueueAsync(
            NotificationKind.Avviso,
            destinatari,
            titolo: dto.Importante ? $"{team.Nome}: avviso importante" : $"{team.Nome}: nuovo avviso",
            corpo: $"{announcement.Titolo} - {announcement.Contenuto}",
            url: "/bacheca",
            tag: $"avviso-{announcement.Id}",
            teamId: teamId);

        return MapToDto(announcement, authorId, totalPlayers);
    }

    public async Task DeleteAsync(int teamId, int announcementId)
    {
        var announcement = await _context.Announcements
            .FirstOrDefaultAsync(a => a.Id == announcementId && a.TeamId == teamId);

        if (announcement == null)
            throw new NotFoundException("Comunicazione", announcementId);

        _context.Announcements.Remove(announcement);
        await _context.SaveChangesAsync();
    }

    public async Task<bool> AcknowledgeAsync(int teamId, int announcementId, int playerId)
    {
        // La comunicazione deve appartenere al team del chiamante (no IDOR cross-team)
        var announcement = await _context.Announcements
            .FirstOrDefaultAsync(a => a.Id == announcementId && a.TeamId == teamId);
        if (announcement == null) throw new NotFoundException("Comunicazione", announcementId);

        var player = await _context.Players
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        var exists = await _context.AnnouncementReads
            .AnyAsync(r => r.AnnouncementId == announcementId && r.PlayerId == playerId);
        if (exists) return true; // Already acknowledged

        var read = new AnnouncementRead
        {
            AnnouncementId = announcementId,
            PlayerId = playerId,
            ReadAt = DateTime.UtcNow
        };

        _context.AnnouncementReads.Add(read);
        await _context.SaveChangesAsync();
        return true;
    }

    private static AnnouncementDto MapToDto(Announcement a, int currentPlayerId, int totalPlayers) => new()
    {
        Id = a.Id,
        TeamId = a.TeamId,
        AuthorId = a.AuthorId,
        AutoreNome = a.AutoreNome,
        AutoreSoprannome = a.AutoreSoprannome,
        Titolo = a.Titolo,
        Contenuto = a.Contenuto,
        Importante = a.Importante,
        CreatedAt = a.CreatedAt,
        TotalePresaVisione = a.Reads?.Count ?? 0,
        TotaleGiocatori = totalPlayers,
        HoPresaVisione = a.Reads?.Any(r => r.PlayerId == currentPlayerId) ?? false
    };
}
