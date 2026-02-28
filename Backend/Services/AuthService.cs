using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> RegisterAsync(RegisterRequest request, int adminPlayerId);
    Task<LoginResponse> RefreshTokenAsync(RefreshTokenRequest request);
    Task<PlayerInfo?> GetCurrentPlayerAsync(int userId, int? teamId = null);
    Task<LoginResponse> SelectTeamAsync(int userId, int teamId);
    Task<List<TeamMembershipInfo>> GetUserTeamsAsync(int userId);
    Task<LoginResponse> CreateTeamAsync(int userId, CreateTeamRequest request);
    Task<LoginResponse> JoinTeamAsync(int userId, JoinTeamRequest request);
    Task<string> GetTeamInviteCodeAsync(int teamId);
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
            .FirstOrDefaultAsync(u => u.Email == request.Email && u.IsActive);

        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            _logger.LogWarning("Tentativo di login fallito per email: {Email}", request.Email);
            throw new UnauthorizedException("Email o password non validi");
        }

        var players = user.Players.ToList();
        if (players.Count == 0)
            throw new BusinessException("Account non associato a nessun giocatore");

        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        _logger.LogInformation("Login effettuato per utente: {UserId}", user.Id);

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
            Teams = players.Select(p => new TeamMembershipInfo
            {
                TeamId = p.TeamId,
                PlayerId = p.Id,
                TeamName = p.Team.Nome,
                Ruolo = p.Ruolo.ToString()
            }).ToList()
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

        var player = new Player
        {
            TeamId = request.TeamId,
            UserId = user.Id,
            Nome = request.Nome,
            Soprannome = request.Soprannome,
            Telefono = request.Telefono,
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
            .FirstOrDefaultAsync(rt => rt.Token == request.RefreshToken);

        if (storedToken == null || !storedToken.IsActive)
            throw new UnauthorizedException("Refresh token non valido o scaduto");

        var user = storedToken.User;
        var players = user.Players.ToList();
        if (players.Count == 0)
            throw new BusinessException("Account non associato a nessun giocatore");

        storedToken.RevokedAt = DateTime.UtcNow;

        // Usa il teamId dal request se fornito, altrimenti primo player
        var player = request.TeamId.HasValue
            ? players.FirstOrDefault(p => p.TeamId == request.TeamId.Value) ?? players.First()
            : players.First();

        var accessToken = GenerateAccessToken(user, player);
        var newRefreshToken = await GenerateRefreshTokenAsync(user.Id);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        await _context.SaveChangesAsync();

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = newRefreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = MapToPlayerInfo(user, player)
        };
    }

    public async Task<PlayerInfo?> GetCurrentPlayerAsync(int userId, int? teamId = null)
    {
        var user = await _context.Users
            .Include(u => u.Players)
                .ThenInclude(p => p.Team)
            .FirstOrDefaultAsync(u => u.Id == userId && u.IsActive);

        if (user == null || user.Players.Count == 0) return null;

        var player = teamId.HasValue
            ? user.Players.FirstOrDefault(p => p.TeamId == teamId.Value)
            : user.Players.FirstOrDefault();

        if (player == null) return null;
        return MapToPlayerInfo(user, player);
    }

    public async Task<LoginResponse> SelectTeamAsync(int userId, int teamId)
    {
        var player = await _context.Players
            .Include(p => p.Team)
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
            .Where(p => p.UserId == userId)
            .ToListAsync();

        return players.Select(p => new TeamMembershipInfo
        {
            TeamId = p.TeamId,
            PlayerId = p.Id,
            TeamName = p.Team.Nome,
            Ruolo = p.Ruolo.ToString()
        }).ToList();
    }

    public async Task<LoginResponse> CreateTeamAsync(int userId, CreateTeamRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            throw new NotFoundException("Utente", userId);

        // Genera codice invito unico
        var inviteCode = GenerateInviteCode();

        var team = new Team
        {
            Nome = request.NomeTeam,
            PartitePerStagione = request.PartitePerStagione,
            GettoniPerGiocatore = request.GettoniPerGiocatore,
            UseGettoni = request.UseGettoni,
            InviteCode = inviteCode,
            CreatedAt = DateTime.UtcNow
        };
        _context.Teams.Add(team);
        await _context.SaveChangesAsync();

        var player = new Player
        {
            TeamId = team.Id,
            UserId = userId,
            Nome = request.NomeGiocatore,
            Soprannome = request.Soprannome,
            Ruolo = UserRole.Admin,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Nuovo team creato: {TeamId} - {TeamName} da utente {UserId}", team.Id, team.Nome, userId);

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

    public async Task<LoginResponse> JoinTeamAsync(int userId, JoinTeamRequest request)
    {
        var team = await _context.Teams.FirstOrDefaultAsync(t => t.InviteCode == request.InviteCode);
        if (team == null)
            throw new NotFoundException("Codice invito non valido");

        // Verifica che l'utente non sia già nel team
        var existing = await _context.Players.AnyAsync(p => p.UserId == userId && p.TeamId == team.Id);
        if (existing)
            throw new ConflictException("Sei gia' in questo team");

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            throw new NotFoundException("Utente", userId);

        var player = new Player
        {
            TeamId = team.Id,
            UserId = userId,
            Nome = request.Nome,
            Soprannome = request.Soprannome,
            Telefono = request.Telefono,
            Ruolo = UserRole.User,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(player);
        await _context.SaveChangesAsync();

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
