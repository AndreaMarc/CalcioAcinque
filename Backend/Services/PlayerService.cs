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
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Team", teamId);

        var players = await _context.Players.Where(p => p.TeamId == teamId).OrderBy(p => p.Nome).ToListAsync();
        return players.Select(p => MapToDto(p, team.RegimePagamentoDefault)).ToList();
    }

    public async Task<PlayerDetailDto> GetByIdAsync(int teamId, int playerId)
    {
        var player = await _context.Players.Include(p => p.User).Include(p => p.Attendances).Include(p => p.Team)
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        return new PlayerDetailDto
        {
            Id = player.Id, TeamId = player.TeamId, UserId = player.UserId,
            ClubMemberId = player.ClubMemberId, Nome = player.Nome,
            Soprannome = player.Soprannome, Telefono = player.Telefono, Ruolo = player.Ruolo.ToString(),
            Posizione = player.Posizione?.ToString(), NumeroMaglia = player.NumeroMaglia,
            GettoniTotali = player.GettoniTotali, GettoniConsumati = player.GettoniConsumati,
            GettoniRimanenti = player.GettoniRimanenti, IscrizionePagata = player.IscrizionePagata,
            TesseramentoPagato = player.TesseramentoPagato, CreatedAt = player.CreatedAt,
            RegimePagamento = player.RegimePagamento?.ToString(),
            RegimePagamentoEffettivo = RegimiPagamento
                .Effettivo(player.RegimePagamento, player.Team.RegimePagamentoDefault).ToString(),
            Email = player.User.Email,
            PartiteConvocato = player.Attendances.Count(a => a.Convocato),
            PartitePresente = player.Attendances.Count(a => a.Presente),
            PartiteGiocate = player.Attendances.Count(a => a.HaGiocato),
            AltreSquadre = await GetOtherTeamsAsync(player)
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

        // Se la squadra appartiene a una societa', il giocatore entra anche nell'anagrafica
        // condivisa: se ci gioca gia' in un'altra squadra della societa' e' lo stesso membro.
        ClubMember? member = null;
        if (team.ClubId.HasValue)
        {
            member = await GetOrCreateMemberAsync(team.ClubId.Value, user.Id, dto.Nome, dto.Soprannome, dto.Telefono);
            await _context.SaveChangesAsync();
        }

        var ruolo = Enum.TryParse<UserRole>(dto.Ruolo, true, out var parsed) ? parsed : UserRole.User;
        var player = new Player
        {
            TeamId = teamId,
            UserId = user.Id,
            ClubMemberId = member?.Id,
            Nome = member?.Nome ?? dto.Nome,
            Soprannome = member?.Soprannome ?? dto.Soprannome,
            Telefono = member?.Telefono ?? dto.Telefono,
            Ruolo = ruolo,
            Posizione = ClubService.ParsePosition(dto.Posizione, team.Formato),
            NumeroMaglia = dto.NumeroMaglia,
            RegimePagamento = ParseRegime(dto.RegimePagamento),
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();
        return MapToDto(player, team.RegimePagamentoDefault);
    }

    public async Task<PlayerDto> UpdateAsync(int teamId, int playerId, UpdatePlayerDto dto)
    {
        var player = await _context.Players
            .Include(p => p.Team)
            .FirstOrDefaultAsync(p => p.Id == playerId && p.TeamId == teamId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);

        // Dati anagrafici: scritti sull'anagrafica di societa' e propagati alle altre squadre
        await UpdateIdentityAsync(player, dto.Nome, dto.Soprannome, dto.Telefono);

        if (dto.IscrizionePagata.HasValue) player.IscrizionePagata = dto.IscrizionePagata.Value;
        if (dto.TesseramentoPagato.HasValue) player.TesseramentoPagato = dto.TesseramentoPagato.Value;
        if (dto.Ruolo != null && Enum.TryParse<UserRole>(dto.Ruolo, true, out var parsedRole)) player.Ruolo = parsedRole;

        // Ruolo in campo e numero valgono solo per questa squadra
        if (dto.Posizione != null)
            player.Posizione = dto.Posizione.Length == 0
                ? null
                : ClubService.ParsePosition(dto.Posizione, player.Team.Formato);
        if (dto.NumeroMaglia.HasValue)
            player.NumeroMaglia = dto.NumeroMaglia.Value <= 0 ? null : dto.NumeroMaglia.Value;

        // Stringa vuota = nessuna scelta personale, torna a valere il default della squadra
        if (dto.RegimePagamento != null)
            player.RegimePagamento = ParseRegime(dto.RegimePagamento);

        await _context.SaveChangesAsync();
        return MapToDto(player, player.Team.RegimePagamentoDefault);
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
        var clubMemberId = player.ClubMemberId;

        // Rimuovi player (cascade elimina convocations, attendances, etc.)
        _context.Players.Remove(player);
        await _context.SaveChangesAsync();

        // L'anagrafica di societa' resta finche' la persona gioca in almeno una squadra
        if (clubMemberId.HasValue)
        {
            var stillPlaying = await _context.Players.AnyAsync(p => p.ClubMemberId == clubMemberId.Value);
            if (!stillPlaying)
            {
                var member = await _context.ClubMembers.FindAsync(clubMemberId.Value);
                if (member != null) _context.ClubMembers.Remove(member);
                await _context.SaveChangesAsync();
            }
        }

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

        await UpdateIdentityAsync(player, dto.Nome, dto.Soprannome, dto.Telefono);
        await _context.SaveChangesAsync();

        var team = await _context.Teams.FindAsync(teamId);
        return MapToDto(player, team?.RegimePagamentoDefault ?? RegimePagamento.Stagionale);
    }

    // ---------------------------------------------------------------- interni

    /// <summary>
    /// Aggiorna i dati anagrafici. Se il giocatore ha un'anagrafica di societa', la modifica
    /// vale per tutte le squadre in cui gioca (e' la stessa persona); altrimenti resta locale.
    /// </summary>
    private async Task UpdateIdentityAsync(Player player, string? nome, string? soprannome, string? telefono)
    {
        if (nome == null && soprannome == null && telefono == null) return;

        if (player.ClubMemberId.HasValue)
        {
            var member = await _context.ClubMembers
                .Include(m => m.Players)
                .FirstOrDefaultAsync(m => m.Id == player.ClubMemberId.Value);

            if (member != null)
            {
                if (nome != null) member.Nome = nome;
                if (soprannome != null) member.Soprannome = soprannome;
                if (telefono != null) member.Telefono = telefono;
                ClubService.SyncMemberToPlayers(member);
                return;
            }
        }

        if (nome != null) player.Nome = nome;
        if (soprannome != null) player.Soprannome = soprannome;
        if (telefono != null) player.Telefono = telefono;
    }

    private async Task<ClubMember> GetOrCreateMemberAsync(
        int clubId, int userId, string nome, string? soprannome, string? telefono)
    {
        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.ClubId == clubId && m.UserId == userId);

        if (member != null)
        {
            // La persona e' gia' in anagrafica perche' gioca in un'altra squadra della
            // societa': i suoi dati restano quelli, si riempiono solo i campi vuoti.
            // Rinominarla si fa dall'anagrafica di societa', non aggiungendola a una squadra.
            if (string.IsNullOrWhiteSpace(member.Soprannome) && !string.IsNullOrWhiteSpace(soprannome))
                member.Soprannome = soprannome;
            if (string.IsNullOrWhiteSpace(member.Telefono) && !string.IsNullOrWhiteSpace(telefono))
                member.Telefono = telefono;
            ClubService.SyncMemberToPlayers(member);
            return member;
        }

        member = new ClubMember
        {
            ClubId = clubId,
            UserId = userId,
            Nome = nome.Trim(),
            Soprannome = soprannome,
            Telefono = telefono,
            CreatedAt = DateTime.UtcNow
        };
        _context.ClubMembers.Add(member);
        return member;
    }

    /// <summary>Le altre squadre della societa' in cui gioca la stessa persona.</summary>
    private async Task<List<PlayerOtherTeamDto>> GetOtherTeamsAsync(Player player)
    {
        if (!player.ClubMemberId.HasValue) return new List<PlayerOtherTeamDto>();

        var siblings = await _context.Players
            .Include(p => p.Team)
            .Where(p => p.ClubMemberId == player.ClubMemberId.Value && p.Id != player.Id)
            .ToListAsync();

        return siblings.Select(p => new PlayerOtherTeamDto
        {
            TeamId = p.TeamId,
            PlayerId = p.Id,
            TeamNome = p.Team.Nome,
            Formato = p.Team.Formato.ToString(),
            FormatoShortLabel = TeamFormats.Preset(p.Team.Formato).ShortLabel,
            Posizione = p.Posizione?.ToString()
        }).OrderBy(x => x.TeamNome).ToList();
    }

    private static RegimePagamento? ParseRegime(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        return Enum.TryParse<RegimePagamento>(value, true, out var regime) ? regime : null;
    }

    private static PlayerDto MapToDto(Player p, RegimePagamento defaultSquadra) => new()
    {
        Id = p.Id, TeamId = p.TeamId, UserId = p.UserId, ClubMemberId = p.ClubMemberId,
        Nome = p.Nome, Soprannome = p.Soprannome,
        Telefono = p.Telefono, Ruolo = p.Ruolo.ToString(),
        Posizione = p.Posizione?.ToString(), NumeroMaglia = p.NumeroMaglia,
        GettoniTotali = p.GettoniTotali,
        GettoniConsumati = p.GettoniConsumati, GettoniRimanenti = p.GettoniRimanenti,
        IscrizionePagata = p.IscrizionePagata, TesseramentoPagato = p.TesseramentoPagato,
        RegimePagamento = p.RegimePagamento?.ToString(),
        RegimePagamentoEffettivo = RegimiPagamento.Effettivo(p.RegimePagamento, defaultSquadra).ToString(),
        CreatedAt = p.CreatedAt
    };
}
