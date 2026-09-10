using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> SignupAsync(SignupRequest request);
    Task<LoginResponse> RegisterAsync(RegisterRequest request, int adminPlayerId);
    Task<LoginResponse> RefreshTokenAsync(RefreshTokenRequest request);
    Task<MeResponse?> GetMeAsync(int userId, int? teamId = null);
    Task<LoginResponse> SelectTeamAsync(int userId, int teamId);
    Task<List<TeamMembershipInfo>> GetUserTeamsAsync(int userId);
    Task<LoginResponse> CreateTeamAsync(int userId, CreateTeamRequest request);
    Task<LoginResponse> JoinTeamAsync(int userId, JoinTeamRequest request);
    Task<string> GetTeamInviteCodeAsync(int teamId);
    Task<JoinInfoResponse?> GetJoinInfoAsync(string inviteCode);
}

public class AuthService : IAuthService
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthService> _logger;

    public AuthService(ApplicationDbContext context, IConfiguration configuration, ILogger<AuthService> logger)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        var user = await _context.Users
            .Include(u => u.Players)
                .ThenInclude(p => p.Team)
                    .ThenInclude(t => t.Club)
            .FirstOrDefaultAsync(u => u.Email == request.Email && u.IsActive);

        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            _logger.LogWarning("Tentativo di login fallito per email: {Email}", request.Email);
            throw new UnauthorizedException("Email o password non validi");
        }

        var players = user.Players.ToList();

        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        _logger.LogInformation("Login effettuato per utente: {UserId}", user.Id);

        if (players.Count == 0)
        {
            // Nessun team — token di sessione, l'utente passa da onboarding (draft o crea/unisciti)
            var onboardingToken = GenerateSessionToken(user);
            var onboardingRefresh = await GenerateRefreshTokenAsync(user.Id);

            return new LoginResponse
            {
                AccessToken = onboardingToken,
                RefreshToken = onboardingRefresh.Token,
                AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(10),
                Player = null,
                Teams = new List<TeamMembershipInfo>()
            };
        }

        if (players.Count == 1)
        {
            // Un solo team → auto-select (retrocompatibile)
            var player = players.First();
            var accessToken = GenerateAccessToken(user, player);
            var refreshToken = await GenerateRefreshTokenAsync(user.Id);

            return new LoginResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken.Token,
                AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
                Player = MapToPlayerInfo(user, player)
            };
        }

        // Più team → token di sessione + lista team
        var sessionToken = GenerateSessionToken(user);
        var sessionRefresh = await GenerateRefreshTokenAsync(user.Id);

        return new LoginResponse
        {
            AccessToken = sessionToken,
            RefreshToken = sessionRefresh.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(5),
            Player = null,
            Teams = players.Select(MapToMembership).ToList()
        };
    }

    public async Task<LoginResponse> SignupAsync(SignupRequest request)
    {
        var existing = await _context.Users.AnyAsync(u => u.Email == request.Email);
        if (existing)
            throw new ConflictException("Esiste già un account con questa email");

        var user = new User
        {
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Nuovo utente registrato (senza team): {UserId} - {Email}", user.Id, user.Email);

        var sessionToken = GenerateSessionToken(user);
        var sessionRefresh = await GenerateRefreshTokenAsync(user.Id);

        return new LoginResponse
        {
            AccessToken = sessionToken,
            RefreshToken = sessionRefresh.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(10),
            Player = null,
            Teams = new List<TeamMembershipInfo>()
        };
    }

    public async Task<LoginResponse> RegisterAsync(RegisterRequest request, int adminPlayerId)
    {
        var team = await _context.Teams.FindAsync(request.TeamId);
        if (team == null)
            throw new NotFoundException("Team", request.TeamId);

        var existingUser = await _context.Users
            .Include(u => u.Players)
            .FirstOrDefaultAsync(u => u.Email == request.Email);

        User user;
        if (existingUser != null)
        {
            // Utente esiste già — verifica che non sia già in questo team
            if (existingUser.Players.Any(p => p.TeamId == request.TeamId))
                throw new ConflictException("Questo utente e' gia' nel team");
            user = existingUser;
        }
        else
        {
            // Nuovo utente
            user = new User
            {
                Email = request.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();
        }

        ClubMember? member = null;
        if (team.ClubId.HasValue)
        {
            member = await GetOrCreateClubMemberAsync(
                team.ClubId.Value, user.Id, request.Nome, request.Soprannome, request.Telefono);
            await _context.SaveChangesAsync();
        }

        var player = new Player
        {
            TeamId = request.TeamId,
            UserId = user.Id,
            ClubMemberId = member?.Id,
            Nome = member?.Nome ?? request.Nome,
            Soprannome = member?.Soprannome ?? request.Soprannome,
            Telefono = member?.Telefono ?? request.Telefono,
            Ruolo = UserRole.User,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };

        _context.Players.Add(player);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Nuovo giocatore registrato: {PlayerId} - {Email}", player.Id, user.Email);

        var accessToken = GenerateAccessToken(user, player);
        var refreshToken = await GenerateRefreshTokenAsync(user.Id);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(user, player)
        };
    }

    public async Task<LoginResponse> RefreshTokenAsync(RefreshTokenRequest request)
    {
        var storedToken = await _context.RefreshTokens
            .Include(rt => rt.User)
                .ThenInclude(u => u.Players)
                    .ThenInclude(p => p.Team)
                        .ThenInclude(t => t.Club)
            .FirstOrDefaultAsync(rt => rt.Token == request.RefreshToken);

        if (storedToken == null || !storedToken.IsActive)
            throw new UnauthorizedException("Refresh token non valido o scaduto");

        var user = storedToken.User;
        var players = user.Players.ToList();
        storedToken.RevokedAt = DateTime.UtcNow;

        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        if (players.Count == 0)
        {
            // Utente senza team → restituiamo session token
            var sessionToken = GenerateSessionToken(user);
            var sessionRefresh = await GenerateRefreshTokenAsync(user.Id);
            await _context.SaveChangesAsync();
            return new LoginResponse
            {
                AccessToken = sessionToken,
                RefreshToken = sessionRefresh.Token,
                AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(10),
                Player = null,
                Teams = new List<TeamMembershipInfo>()
            };
        }

        // Usa il teamId dal request se fornito, altrimenti primo player
        var player = request.TeamId.HasValue
            ? players.FirstOrDefault(p => p.TeamId == request.TeamId.Value) ?? players.First()
            : players.First();

        var accessToken = GenerateAccessToken(user, player);
        var newRefreshToken = await GenerateRefreshTokenAsync(user.Id);

        await _context.SaveChangesAsync();

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = newRefreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(user, player)
        };
    }

    public async Task<MeResponse?> GetMeAsync(int userId, int? teamId = null)
    {
        var user = await _context.Users
            .Include(u => u.Players)
                .ThenInclude(p => p.Team)
                    .ThenInclude(t => t.Club)
            .FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);

        if (user == null) return null;

        var players = user.Players.ToList();

        if (players.Count == 0)
        {
            return new MeResponse { Player = null, Teams = new List<TeamMembershipInfo>() };
        }

        var player = teamId.HasValue
            ? players.FirstOrDefault(p => p.TeamId == teamId.Value) ?? players.First()
            : players.First();

        var teams = players.Select(MapToMembership).ToList();

        return new MeResponse
        {
            Player = MapToPlayerInfo(user, player),
            Teams = teams
        };
    }

    public async Task<LoginResponse> SelectTeamAsync(int userId, int teamId)
    {
        var player = await _context.Players
            .Include(p => p.Team)
                .ThenInclude(t => t.Club)
            .Include(p => p.User)
            .FirstOrDefaultAsync(p => p.UserId == userId && p.TeamId == teamId);

        if (player == null)
            throw new UnauthorizedException("Non appartieni a questo team");

        var accessToken = GenerateAccessToken(player.User, player);
        var refreshToken = await GenerateRefreshTokenAsync(userId);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(player.User, player)
        };
    }

    public async Task<List<TeamMembershipInfo>> GetUserTeamsAsync(int userId)
    {
        var players = await _context.Players
            .Include(p => p.Team)
                .ThenInclude(t => t.Club)
            .Where(p => p.UserId == userId)
            .ToListAsync();

        return players.Select(MapToMembership).ToList();
    }

    public async Task<LoginResponse> CreateTeamAsync(int userId, CreateTeamRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            throw new NotFoundException("Utente", userId);

        var club = await ResolveClubForNewTeamAsync(userId, request);

        var team = new Team
        {
            ClubId = club.Id,
            Nome = request.NomeTeam,
            Formato = ClubService.ParseFormat(request.Formato),
            PartitePerStagione = request.PartitePerStagione,
            GettoniPerGiocatore = request.GettoniPerGiocatore,
            UseGettoni = request.UseGettoni,
            QuotaIscrizione = request.QuotaIscrizione,
            QuotaTesseramento = request.QuotaTesseramento,
            CostoPartita = request.CostoPartita,
            InviteCode = await GenerateUniqueTeamCodeAsync(),
            CreatedAt = DateTime.UtcNow
        };
        team.ApplyFormatDefaults();
        _context.Teams.Add(team);
        await _context.SaveChangesAsync();

        var member = await GetOrCreateClubMemberAsync(club.Id, userId, request.NomeGiocatore, request.Soprannome, null);
        await _context.SaveChangesAsync();

        var player = new Player
        {
            TeamId = team.Id,
            UserId = userId,
            ClubMemberId = member.Id,
            Nome = member.Nome,
            Soprannome = member.Soprannome,
            Telefono = member.Telefono,
            Ruolo = UserRole.Admin,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Nuovo team creato: {TeamId} - {TeamName} ({Formato}) nella societa {ClubId} da utente {UserId}",
            team.Id, team.Nome, team.Formato, club.Id, userId);

        var accessToken = GenerateAccessToken(user, player);
        var refreshToken = await GenerateRefreshTokenAsync(userId);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(user, player)
        };
    }

    /// <summary>
    /// Aggancia la nuova squadra a una societa esistente (serve essere admin) oppure ne crea una.
    /// </summary>
    private async Task<Club> ResolveClubForNewTeamAsync(int userId, CreateTeamRequest request)
    {
        if (request.ClubId.HasValue)
        {
            var existing = await _context.Clubs
                .Include(c => c.Teams).ThenInclude(t => t.Players)
                .FirstOrDefaultAsync(c => c.Id == request.ClubId.Value)
                ?? throw new NotFoundException("Societa", request.ClubId.Value);

            var isAdmin = existing.Teams.Any(t => t.Players.Any(p => p.UserId == userId && p.Ruolo == UserRole.Admin));
            var isEmpty = !existing.Teams.Any(t => t.Players.Count > 0);
            if (!isAdmin && !isEmpty)
                throw new UnauthorizedException("Servono i permessi di amministratore della societa");

            return existing;
        }

        var club = new Club
        {
            Nome = string.IsNullOrWhiteSpace(request.NomeSocieta) ? request.NomeTeam : request.NomeSocieta!.Trim(),
            InviteCode = await GenerateUniqueClubCodeAsync(),
            CreatedAt = DateTime.UtcNow
        };
        _context.Clubs.Add(club);
        await _context.SaveChangesAsync();
        return club;
    }

    public async Task<LoginResponse> JoinTeamAsync(int userId, JoinTeamRequest request)
    {
        var team = await ResolveTeamFromInviteCodeAsync(request.InviteCode, request.TeamId);

        // Verifica che l'utente non sia già nel team
        var existing = await _context.Players.AnyAsync(p => p.UserId == userId && p.TeamId == team.Id);
        if (existing)
            throw new ConflictException("Sei gia' in questo team");

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            throw new NotFoundException("Utente", userId);

        // L'anagrafica vive a livello di societa: la stessa persona in due squadre e' lo stesso membro
        ClubMember? member = null;
        if (team.ClubId.HasValue)
        {
            member = await GetOrCreateClubMemberAsync(
                team.ClubId.Value, userId, request.Nome, request.Soprannome, request.Telefono);
            await _context.SaveChangesAsync();
        }

        var player = new Player
        {
            TeamId = team.Id,
            UserId = userId,
            ClubMemberId = member?.Id,
            Nome = member?.Nome ?? request.Nome,
            Soprannome = member?.Soprannome ?? request.Soprannome,
            Telefono = member?.Telefono ?? request.Telefono,
            Ruolo = UserRole.User,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();

        // Claim opzionale di un PendingPlayer: il nuovo utente "è" uno dei confermati pre-registrati
        if (request.PendingPlayerId.HasValue)
        {
            var pending = await _context.PendingPlayers.FirstOrDefaultAsync(
                p => p.Id == request.PendingPlayerId.Value && p.TeamId == team.Id && !p.Claimed);
            if (pending != null)
            {
                pending.Claimed = true;
                pending.ClaimedByPlayerId = player.Id;
                if (pending.Tesserato) player.TesseramentoPagato = true;
                if (pending.Posizione.HasValue &&
                    TeamFormats.SupportsPosition(team.Formato, pending.Posizione.Value))
                    player.Posizione = pending.Posizione;
                await _context.SaveChangesAsync();
            }
        }

        _logger.LogInformation("Utente {UserId} si e' unito al team {TeamId}", userId, team.Id);

        var accessToken = GenerateAccessToken(user, player);
        var refreshToken = await GenerateRefreshTokenAsync(userId);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(user, player)
        };
    }

    /// <summary>
    /// Un codice invito puo' essere di una squadra o di una societa'. Nel secondo caso
    /// la squadra va indicata esplicitamente, salvo che la societa' ne abbia una sola.
    /// </summary>
    private async Task<Team> ResolveTeamFromInviteCodeAsync(string inviteCode, int? teamId)
    {
        var code = inviteCode.Trim();

        var team = await _context.Teams
            .Include(t => t.Club)
            .FirstOrDefaultAsync(t => t.InviteCode == code);
        if (team != null) return team;

        var club = await _context.Clubs
            .Include(c => c.Teams)
            .FirstOrDefaultAsync(c => c.InviteCode == code);
        if (club == null)
            throw new NotFoundException("Codice invito non valido");

        if (club.Teams.Count == 0)
            throw new BusinessException($"La societa' {club.Nome} non ha ancora squadre");

        var chosen = teamId.HasValue
            ? club.Teams.FirstOrDefault(t => t.Id == teamId.Value)
            : club.Teams.Count == 1 ? club.Teams.First() : null;

        if (chosen == null)
            throw new BadRequestException($"Scegli a quale squadra di {club.Nome} vuoi unirti");

        chosen.Club = club;
        return chosen;
    }

    public async Task<JoinInfoResponse?> GetJoinInfoAsync(string inviteCode)
    {
        var code = inviteCode.Trim();

        var team = await _context.Teams
            .Include(t => t.Club)
            .Include(t => t.Players)
            .FirstOrDefaultAsync(t => t.InviteCode == code);

        if (team != null)
        {
            var option = await MapJoinOptionAsync(team);
            return new JoinInfoResponse
            {
                CodeType = "team",
                TeamName = team.Nome,
                ClubId = team.ClubId,
                ClubName = team.Club?.Nome,
                Teams = new List<JoinTeamOption> { option },
                PendingPlayers = option.PendingPlayers
            };
        }

        var club = await _context.Clubs
            .Include(c => c.Teams).ThenInclude(t => t.Players)
            .FirstOrDefaultAsync(c => c.InviteCode == code);
        if (club == null) return null;

        var options = new List<JoinTeamOption>();
        foreach (var t in club.Teams.OrderBy(x => x.Formato).ThenBy(x => x.Nome))
            options.Add(await MapJoinOptionAsync(t));

        return new JoinInfoResponse
        {
            CodeType = "club",
            // Con una sola squadra il client si comporta esattamente come col codice squadra
            TeamName = options.Count == 1 ? options[0].Nome : string.Empty,
            ClubId = club.Id,
            ClubName = club.Nome,
            Teams = options,
            PendingPlayers = options.Count == 1 ? options[0].PendingPlayers : new List<PendingPlayerDto>()
        };
    }

    private async Task<JoinTeamOption> MapJoinOptionAsync(Team team)
    {
        var pending = await _context.PendingPlayers
            .Where(p => p.TeamId == team.Id && !p.Claimed)
            .OrderBy(p => p.Nome)
            .ToListAsync();

        return new JoinTeamOption
        {
            TeamId = team.Id,
            Nome = team.Nome,
            Formato = team.Formato.ToString(),
            FormatoLabel = TeamFormats.Label(team.Formato),
            TotaleGiocatori = team.Players?.Count ?? await _context.Players.CountAsync(p => p.TeamId == team.Id),
            PendingPlayers = pending.Select(p => new PendingPlayerDto
            {
                Id = p.Id,
                Nome = p.Nome,
                Soprannome = p.Soprannome,
                Posizione = p.Posizione?.ToString(),
                Bravura = p.Bravura,
                Affidabilita = p.Affidabilita,
                Tesserato = p.Tesserato,
                Note = p.Note
            }).ToList()
        };
    }

    /// <summary>
    /// Recupera o crea l'anagrafica di societa' per l'utente. E' il punto in cui i giocatori
    /// comuni a due squadre della stessa societa' vengono riconosciuti come la stessa persona.
    /// </summary>
    private async Task<ClubMember> GetOrCreateClubMemberAsync(
        int clubId, int userId, string? nome, string? soprannome, string? telefono)
    {
        var member = await _context.ClubMembers
            .Include(m => m.Players)
            .FirstOrDefaultAsync(m => m.ClubId == clubId && m.UserId == userId);

        if (member != null)
        {
            if (!string.IsNullOrWhiteSpace(nome)) member.Nome = nome!.Trim();
            if (!string.IsNullOrWhiteSpace(soprannome)) member.Soprannome = soprannome;
            if (!string.IsNullOrWhiteSpace(telefono)) member.Telefono = telefono;
            ClubService.SyncMemberToPlayers(member);
            return member;
        }

        member = new ClubMember
        {
            ClubId = clubId,
            UserId = userId,
            Nome = string.IsNullOrWhiteSpace(nome) ? "Giocatore" : nome!.Trim(),
            Soprannome = soprannome,
            Telefono = telefono,
            CreatedAt = DateTime.UtcNow
        };
        _context.ClubMembers.Add(member);
        return member;
    }

    private async Task<string> GenerateUniqueClubCodeAsync()
    {
        for (var i = 0; i < 10; i++)
        {
            var code = GenerateInviteCode();
            if (!await _context.Clubs.AnyAsync(c => c.InviteCode == code)) return code;
        }
        throw new BusinessException("Impossibile generare un codice invito, riprova");
    }

    private async Task<string> GenerateUniqueTeamCodeAsync()
    {
        for (var i = 0; i < 10; i++)
        {
            var code = GenerateInviteCode();
            if (!await _context.Teams.AnyAsync(t => t.InviteCode == code)) return code;
        }
        throw new BusinessException("Impossibile generare un codice invito, riprova");
    }

    private string GenerateAccessToken(User user, Player player)
    {
        var key = Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!);
        var issuer = _configuration["Jwt:Issuer"];
        var audience = _configuration["Jwt:Audience"];
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, player.Ruolo.ToString()),
            new("PlayerId", player.Id.ToString()),
            new("TeamId", player.TeamId.ToString()),
            new("Nome", player.Nome)
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Issuer = issuer,
            Audience = audience,
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }

    private async Task<RefreshToken> GenerateRefreshTokenAsync(int userId)
    {
        var days = int.Parse(_configuration["Jwt:RefreshTokenExpirationDays"] ?? "30");
        var tokenBytes = RandomNumberGenerator.GetBytes(64);

        var refreshToken = new RefreshToken
        {
            UserId = userId,
            Token = Convert.ToBase64String(tokenBytes),
            ExpiresAt = DateTime.UtcNow.AddDays(days),
            CreatedAt = DateTime.UtcNow
        };

        _context.RefreshTokens.Add(refreshToken);
        await _context.SaveChangesAsync();

        return refreshToken;
    }

    public async Task<string> GetTeamInviteCodeAsync(int teamId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null)
            throw new NotFoundException("Team", teamId);

        if (string.IsNullOrEmpty(team.InviteCode))
        {
            team.InviteCode = GenerateInviteCode();
            await _context.SaveChangesAsync();
        }

        return team.InviteCode;
    }

    private string GenerateSessionToken(User user)
    {
        var key = Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email),
            new("TokenType", "session")
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(10),
            Issuer = _configuration["Jwt:Issuer"],
            Audience = _configuration["Jwt:Audience"],
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        return tokenHandler.WriteToken(tokenHandler.CreateToken(tokenDescriptor));
    }

    private static string GenerateInviteCode()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = RandomNumberGenerator.GetBytes(8);
        var code = new char[8];
        for (int i = 0; i < 8; i++)
            code[i] = chars[random[i] % chars.Length];
        return new string(code);
    }

    private static TeamMembershipInfo MapToMembership(Player player)
    {
        var preset = TeamFormats.Preset(player.Team.Formato);
        return new TeamMembershipInfo
        {
            TeamId = player.TeamId,
            PlayerId = player.Id,
            TeamName = player.Team.Nome,
            Ruolo = player.Ruolo.ToString(),
            ClubId = player.Team.ClubId,
            ClubName = player.Team.Club?.Nome,
            Formato = player.Team.Formato.ToString(),
            FormatoLabel = preset.Label,
            FormatoShortLabel = preset.ShortLabel
        };
    }

    private static PlayerInfo MapToPlayerInfo(User user, Player player)
    {
        return new PlayerInfo
        {
            Id = player.Id,
            UserId = user.Id,
            TeamId = player.TeamId,
            Email = user.Email,
            Nome = player.Nome,
            Soprannome = player.Soprannome,
            Ruolo = player.Ruolo.ToString()
        };
    }
}
