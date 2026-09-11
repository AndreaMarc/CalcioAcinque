using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Clubs;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IClubService
{
    List<TeamFormatDto> GetFormats();

    Task<List<ClubDto>> GetMyClubsAsync(int userId);
    Task<ClubDto> GetByIdAsync(int userId, int clubId);
    Task<ClubDto> CreateAsync(int userId, CreateClubDto dto);
    Task<ClubDto> UpdateAsync(int userId, int clubId, UpdateClubDto dto);
    Task<string> GetInviteCodeAsync(int userId, int clubId);
    Task<ClubTeamDto> CreateTeamAsync(int userId, int clubId, CreateClubTeamDto dto);

    Task<List<ClubMemberDto>> GetMembersAsync(int userId, int clubId);
    Task<ClubMemberDto> CreateMemberAsync(int userId, int clubId, UpsertClubMemberDto dto);
    Task<ClubMemberDto> UpdateMemberAsync(int userId, int clubId, int memberId, UpsertClubMemberDto dto);
    Task DeleteMemberAsync(int userId, int clubId, int memberId);
    Task<ClubMemberDto> AssignToTeamAsync(int userId, int clubId, int memberId, AssignMemberToTeamDto dto);
    Task<ClubMemberDto> RemoveFromTeamAsync(int userId, int clubId, int memberId, int targetTeamId);
}

public class ClubService : IClubService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<ClubService> _logger;

    public ClubService(ApplicationDbContext context, ILogger<ClubService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public List<TeamFormatDto> GetFormats() => TeamFormats.All.Select(MapFormat).ToList();

    // ---------------------------------------------------------------- societa

    public async Task<List<ClubDto>> GetMyClubsAsync(int userId)
    {
        var clubIds = await MyClubIdsAsync(userId);
        if (clubIds.Count == 0) return new List<ClubDto>();

        var clubs = await _context.Clubs
            .Include(c => c.Teams).ThenInclude(t => t.Players)
            .Include(c => c.Members)
            .Where(c => clubIds.Contains(c.Id))
            .OrderBy(c => c.Nome)
            .ToListAsync();

        return clubs.Select(c => MapToDto(c, userId)).ToList();
    }

    public async Task<ClubDto> GetByIdAsync(int userId, int clubId)
    {
        var club = await LoadClubAsync(clubId);
        EnsureMember(userId, club);
        return MapToDto(club, userId);
    }

    public async Task<ClubDto> CreateAsync(int userId, CreateClubDto dto)
    {
        var user = await _context.Users.FindAsync(userId) ?? throw new NotFoundException("Utente", userId);

        var club = new Club
        {
            Nome = dto.Nome.Trim(),
            InviteCode = await GenerateUniqueClubCodeAsync(),
            CreatedByUserId = userId,
            CreatedAt = DateTime.UtcNow
        };
        _context.Clubs.Add(club);
        await _context.SaveChangesAsync();

        _context.ClubMembers.Add(new ClubMember
        {
            ClubId = club.Id,
            UserId = userId,
            Nome = user.Email.Split('@')[0],
            CreatedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        _logger.LogInformation("Nuova societa creata: {ClubId} - {Nome} da utente {UserId}", club.Id, club.Nome, userId);
        return MapToDto(await LoadClubAsync(club.Id), userId);
    }

    public async Task<ClubDto> UpdateAsync(int userId, int clubId, UpdateClubDto dto)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        if (!string.IsNullOrWhiteSpace(dto.Nome)) club.Nome = dto.Nome.Trim();

        // Stringa vuota = cancella il dato; null = lascia invariato
        if (dto.PaypalLink != null) club.PaypalLink = Vuoto(dto.PaypalLink);
        if (dto.Iban != null) club.Iban = Vuoto(dto.Iban)?.Replace(" ", string.Empty).ToUpperInvariant();
        if (dto.IntestatarioIban != null) club.IntestatarioIban = Vuoto(dto.IntestatarioIban);

        await _context.SaveChangesAsync();
        return MapToDto(club, userId);
    }

    public async Task<string> GetInviteCodeAsync(int userId, int clubId)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        if (string.IsNullOrEmpty(club.InviteCode))
        {
            club.InviteCode = await GenerateUniqueClubCodeAsync();
            await _context.SaveChangesAsync();
        }
        return club.InviteCode;
    }

    public async Task<ClubTeamDto> CreateTeamAsync(int userId, int clubId, CreateClubTeamDto dto)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var formato = ParseFormat(dto.Formato);
        var team = new Team
        {
            ClubId = club.Id,
            Nome = dto.Nome.Trim(),
            Formato = formato,
            PartitePerStagione = dto.PartitePerStagione,
            GettoniPerGiocatore = dto.GettoniPerGiocatore,
            UseGettoni = dto.UseGettoni,
            QuotaIscrizione = dto.QuotaIscrizione,
            QuotaTesseramento = dto.QuotaTesseramento,
            CostoPartita = dto.CostoPartita,
            InviteCode = await GenerateUniqueTeamCodeAsync(),
            CreatedAt = DateTime.UtcNow
        };
        team.ApplyFormatDefaults();
        _context.Teams.Add(team);
        await _context.SaveChangesAsync();

        if (dto.IscriviMi)
        {
            var member = await GetOrCreateMemberForUserAsync(club.Id, userId);
            await _context.SaveChangesAsync();
            CreatePlayer(team, member, UserRole.Admin, posizione: null, numeroMaglia: null);
            await _context.SaveChangesAsync();
        }

        _logger.LogInformation("Nuova squadra {TeamId} ({Formato}) nella societa {ClubId}", team.Id, team.Formato, club.Id);

        await _context.Entry(team).Collection(t => t.Players).LoadAsync();
        return MapTeam(team, userId);
    }

    // ---------------------------------------------------------------- anagrafica

    public async Task<List<ClubMemberDto>> GetMembersAsync(int userId, int clubId)
    {
        var club = await LoadClubAsync(clubId);
        EnsureMember(userId, club);

        var members = await _context.ClubMembers
            .Include(m => m.User)
            .Include(m => m.Players).ThenInclude(p => p.Team)
            .Where(m => m.ClubId == clubId)
            .OrderBy(m => m.Nome)
            .ToListAsync();

        return members.Select(MapMember).ToList();
    }

    public async Task<ClubMemberDto> CreateMemberAsync(int userId, int clubId, UpsertClubMemberDto dto)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var member = new ClubMember
        {
            ClubId = clubId,
            Nome = dto.Nome.Trim(),
            Soprannome = dto.Soprannome,
            Telefono = dto.Telefono,
            DataNascita = dto.DataNascita,
            Note = dto.Note,
            CreatedAt = DateTime.UtcNow
        };

        if (!string.IsNullOrWhiteSpace(dto.Email))
            member.UserId = (await GetOrCreateUserAsync(clubId, dto.Email!.Trim(), dto.Password)).Id;

        _context.ClubMembers.Add(member);
        await _context.SaveChangesAsync();
        return await ReloadMemberAsync(member.Id);
    }

    public async Task<ClubMemberDto> UpdateMemberAsync(int userId, int clubId, int memberId, UpsertClubMemberDto dto)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.Id == memberId && m.ClubId == clubId)
            ?? throw new NotFoundException("Membro della societa", memberId);

        member.Nome = dto.Nome.Trim();
        member.Soprannome = dto.Soprannome;
        member.Telefono = dto.Telefono;
        member.DataNascita = dto.DataNascita;
        member.Note = dto.Note;

        if (!string.IsNullOrWhiteSpace(dto.Email) && member.UserId == null)
            member.UserId = (await GetOrCreateUserAsync(clubId, dto.Email!.Trim(), dto.Password)).Id;

        SyncMemberToPlayers(member);
        await _context.SaveChangesAsync();
        return await ReloadMemberAsync(member.Id);
    }

    public async Task DeleteMemberAsync(int userId, int clubId, int memberId)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.Id == memberId && m.ClubId == clubId)
            ?? throw new NotFoundException("Membro della societa", memberId);

        if (member.Players.Count > 0)
            throw new BusinessException("Rimuovi prima la persona da tutte le squadre della societa");

        _context.ClubMembers.Remove(member);
        await _context.SaveChangesAsync();
    }

    public async Task<ClubMemberDto> AssignToTeamAsync(int userId, int clubId, int memberId, AssignMemberToTeamDto dto)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var team = club.Teams.FirstOrDefault(t => t.Id == dto.TeamId)
            ?? throw new NotFoundException("Squadra della societa", dto.TeamId);

        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.Id == memberId && m.ClubId == clubId)
            ?? throw new NotFoundException("Membro della societa", memberId);

        if (member.UserId == null)
            throw new BusinessException(
                "Questa persona non ha ancora un account: aggiungi email e password all'anagrafica prima di iscriverla a una squadra");

        if (member.Players.Any(p => p.TeamId == team.Id))
            throw new ConflictException($"{member.Nome} fa gia parte di {team.Nome}");

        if (await _context.Players.AnyAsync(p => p.TeamId == team.Id && p.UserId == member.UserId))
            throw new ConflictException($"Questo account e gia iscritto a {team.Nome}");

        var ruolo = Enum.TryParse<UserRole>(dto.Ruolo, true, out var parsed) ? parsed : UserRole.User;
        CreatePlayer(team, member, ruolo, ParsePosition(dto.Posizione, team.Formato), dto.NumeroMaglia);
        await _context.SaveChangesAsync();

        return await ReloadMemberAsync(memberId);
    }

    public async Task<ClubMemberDto> RemoveFromTeamAsync(int userId, int clubId, int memberId, int targetTeamId)
    {
        var club = await LoadClubAsync(clubId);
        EnsureAdmin(userId, club);

        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.Id == memberId && m.ClubId == clubId)
            ?? throw new NotFoundException("Membro della societa", memberId);

        var player = member.Players.FirstOrDefault(p => p.TeamId == targetTeamId)
            ?? throw new NotFoundException("Iscrizione alla squadra", targetTeamId);

        if (player.Ruolo == UserRole.Admin)
        {
            var admins = await _context.Players.CountAsync(p => p.TeamId == targetTeamId && p.Ruolo == UserRole.Admin);
            if (admins <= 1) throw new BusinessException("Non puoi rimuovere l'ultimo admin della squadra");
        }

        _context.Players.Remove(player);
        await _context.SaveChangesAsync();
        return await ReloadMemberAsync(memberId);
    }

    // ---------------------------------------------------------------- helper riusati da altri servizi

    /// <summary>Crea (o recupera) l'anagrafica di societa per un utente gia registrato.</summary>
    public async Task<ClubMember> GetOrCreateMemberForUserAsync(
        int clubId, int userId, string? nome = null, string? soprannome = null, string? telefono = null)
    {
        var member = await _context.ClubMembers.FirstOrDefaultAsync(m => m.ClubId == clubId && m.UserId == userId);
        if (member != null)
        {
            if (!string.IsNullOrWhiteSpace(nome)) member.Nome = nome!;
            if (soprannome != null) member.Soprannome = soprannome;
            if (telefono != null) member.Telefono = telefono;
            return member;
        }

        if (string.IsNullOrWhiteSpace(nome))
        {
            var existingPlayer = await _context.Players
                .Where(p => p.UserId == userId && p.Team.ClubId == clubId)
                .FirstOrDefaultAsync();
            nome = existingPlayer?.Nome
                ?? (await _context.Users.FindAsync(userId))?.Email.Split('@')[0]
                ?? "Giocatore";
            soprannome ??= existingPlayer?.Soprannome;
            telefono ??= existingPlayer?.Telefono;
        }

        member = new ClubMember
        {
            ClubId = clubId,
            UserId = userId,
            Nome = nome!,
            Soprannome = soprannome,
            Telefono = telefono,
            CreatedAt = DateTime.UtcNow
        };
        _context.ClubMembers.Add(member);
        return member;
    }

    /// <summary>Allinea i dati anagrafici replicati sulle tessere squadra.</summary>
    public static void SyncMemberToPlayers(ClubMember member)
    {
        foreach (var player in member.Players)
        {
            player.Nome = member.Nome;
            player.Soprannome = member.Soprannome;
            player.Telefono = member.Telefono;
        }
    }

    private static string? Vuoto(string value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    public static string GenerateCode()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = RandomNumberGenerator.GetBytes(8);
        var code = new char[8];
        for (int i = 0; i < 8; i++) code[i] = chars[random[i] % chars.Length];
        return new string(code);
    }

    public static TeamFormat ParseFormat(string? value) =>
        Enum.TryParse<TeamFormat>(value, true, out var f) ? f : TeamFormat.CalcioA5;

    /// <summary>Interpreta un ruolo in campo, scartandolo se non previsto dal formato.</summary>
    public static PlayerPosition? ParsePosition(string? value, TeamFormat formato)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        if (!Enum.TryParse<PlayerPosition>(value, true, out var pos)) return null;
        return TeamFormats.SupportsPosition(formato, pos) ? pos : null;
    }

    public static TeamFormatDto MapFormat(TeamFormatPreset p) => new()
    {
        Valore = p.Formato.ToString(),
        Label = p.Label,
        ShortLabel = p.ShortLabel,
        GiocatoriInCampo = p.GiocatoriInCampo,
        MaxConvocati = p.MaxConvocati,
        MinutiPerTempo = p.MinutiPerTempo,
        NumeroTempi = p.NumeroTempi,
        Posizioni = p.Posizioni.Select(x => x.ToString()).ToList()
    };

    // ---------------------------------------------------------------- interni

    private Player CreatePlayer(Team team, ClubMember member, UserRole ruolo, PlayerPosition? posizione, int? numeroMaglia)
    {
        var player = new Player
        {
            TeamId = team.Id,
            UserId = member.UserId!.Value,
            ClubMemberId = member.Id,
            Nome = member.Nome,
            Soprannome = member.Soprannome,
            Telefono = member.Telefono,
            Ruolo = ruolo,
            Posizione = posizione,
            NumeroMaglia = numeroMaglia,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        return player;
    }

    private async Task<User> GetOrCreateUserAsync(int clubId, string email, string? password)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        if (user != null)
        {
            var alreadyMember = await _context.ClubMembers.AnyAsync(m => m.ClubId == clubId && m.UserId == user.Id);
            if (alreadyMember)
                throw new ConflictException("Questo account fa gia parte dell'anagrafica della societa");
            return user;
        }

        if (string.IsNullOrWhiteSpace(password) || password!.Length < 6)
            throw new BadRequestException("Serve una password di almeno 6 caratteri per creare l'account");

        user = new User
        {
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();
        return user;
    }

    private async Task<List<int>> MyClubIdsAsync(int userId)
    {
        var fromMembers = await _context.ClubMembers
            .Where(m => m.UserId == userId)
            .Select(m => m.ClubId)
            .ToListAsync();
        var fromPlayers = await _context.Players
            .Where(p => p.UserId == userId && p.Team.ClubId != null)
            .Select(p => p.Team.ClubId!.Value)
            .ToListAsync();
        return fromMembers.Concat(fromPlayers).Distinct().ToList();
    }

    private async Task<Club> LoadClubAsync(int clubId) =>
        await _context.Clubs
            .Include(c => c.Teams).ThenInclude(t => t.Players)
            .Include(c => c.Members)
            .FirstOrDefaultAsync(c => c.Id == clubId)
        ?? throw new NotFoundException("Societa", clubId);

    private static void EnsureMember(int userId, Club club)
    {
        if (club.Members.Any(m => m.UserId == userId)) return;
        if (club.Teams.Any(t => t.Players.Any(p => p.UserId == userId))) return;
        throw new UnauthorizedException("Non fai parte di questa societa");
    }

    /// <summary>
    /// Admin di societa = admin in almeno una delle sue squadre. Una societa che non ha
    /// ancora nessun giocatore e amministrata da chi ne e membro (il fondatore).
    /// </summary>
    private static void EnsureAdmin(int userId, Club club)
    {
        EnsureMember(userId, club);
        if (!club.Teams.Any(t => t.Players.Count > 0))
        {
            // Societa' ancora senza giocatori: la gestisce chi l'ha creata, non
            // chiunque sia in anagrafica
            if (club.CreatedByUserId == userId) return;
            throw new UnauthorizedException("Solo chi ha creato la societa puo gestirla finche non ha giocatori");
        }
        if (club.Teams.Any(t => t.Players.Any(p => p.UserId == userId && p.Ruolo == UserRole.Admin))) return;
        throw new UnauthorizedException("Servono i permessi di amministratore della societa");
    }

    private async Task<string> GenerateUniqueClubCodeAsync()
    {
        for (var i = 0; i < 10; i++)
        {
            var code = GenerateCode();
            if (!await _context.Clubs.AnyAsync(c => c.InviteCode == code)) return code;
        }
        throw new BusinessException("Impossibile generare un codice invito, riprova");
    }

    private async Task<string> GenerateUniqueTeamCodeAsync()
    {
        for (var i = 0; i < 10; i++)
        {
            var code = GenerateCode();
            if (!await _context.Teams.AnyAsync(t => t.InviteCode == code)) return code;
        }
        throw new BusinessException("Impossibile generare un codice invito, riprova");
    }

    private async Task<ClubMemberDto> ReloadMemberAsync(int memberId)
    {
        var member = await _context.ClubMembers
            .Include(m => m.User)
            .Include(m => m.Players).ThenInclude(p => p.Team)
            .FirstAsync(m => m.Id == memberId);
        return MapMember(member);
    }

    private static ClubDto MapToDto(Club club, int userId) => new()
    {
        Id = club.Id,
        Nome = club.Nome,
        InviteCode = club.InviteCode,
        CreatedAt = club.CreatedAt,
        TotaleMembri = club.Members?.Count ?? 0,
        PaypalLink = club.PaypalLink,
        Iban = club.Iban,
        IntestatarioIban = club.IntestatarioIban,
        IsAdmin = !club.Teams.Any(t => t.Players.Count > 0)
                  || club.Teams.Any(t => t.Players.Any(p => p.UserId == userId && p.Ruolo == UserRole.Admin)),
        Squadre = club.Teams
            .OrderBy(t => t.Formato)
            .ThenBy(t => t.Nome)
            .Select(t => MapTeam(t, userId))
            .ToList()
    };

    private static ClubTeamDto MapTeam(Team team, int userId)
    {
        var mine = team.Players?.FirstOrDefault(p => p.UserId == userId);
        var preset = TeamFormats.Preset(team.Formato);
        return new ClubTeamDto
        {
            Id = team.Id,
            Nome = team.Nome,
            Formato = team.Formato.ToString(),
            FormatoLabel = preset.Label,
            GiocatoriInCampo = team.GiocatoriInCampo,
            TotaleGiocatori = team.Players?.Count ?? 0,
            MioPlayerId = mine?.Id,
            MioRuolo = mine?.Ruolo.ToString()
        };
    }

    private static ClubMemberDto MapMember(ClubMember m) => new()
    {
        Id = m.Id,
        ClubId = m.ClubId,
        UserId = m.UserId,
        Nome = m.Nome,
        Soprannome = m.Soprannome,
        Telefono = m.Telefono,
        DataNascita = m.DataNascita,
        Note = m.Note,
        Email = m.User?.Email,
        CreatedAt = m.CreatedAt,
        Squadre = m.Players.Select(p => new ClubMemberTeamDto
        {
            TeamId = p.TeamId,
            TeamNome = p.Team?.Nome ?? string.Empty,
            Formato = p.Team?.Formato.ToString() ?? string.Empty,
            FormatoLabel = p.Team != null ? TeamFormats.Label(p.Team.Formato) : string.Empty,
            PlayerId = p.Id,
            Ruolo = p.Ruolo.ToString(),
            Posizione = p.Posizione?.ToString(),
            NumeroMaglia = p.NumeroMaglia,
            GettoniRimanenti = p.GettoniRimanenti,
            IscrizionePagata = p.IscrizionePagata,
            TesseramentoPagato = p.TesseramentoPagato
        }).OrderBy(s => s.TeamNome).ToList()
    };
}
