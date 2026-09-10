using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.DTOs.Draft;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface ITeamDraftService
{
    Task<List<TeamDraftDto>> GetMyDraftsAsync(int userId);
    Task<TeamDraftDto> GetDraftAsync(int userId, int draftId);
    Task<TeamDraftDto> CreateDraftAsync(int userId, UpsertDraftRequest request);
    Task<TeamDraftDto> UpdateDraftAsync(int userId, int draftId, UpsertDraftRequest request);
    Task DeleteDraftAsync(int userId, int draftId);

    Task<DraftCandidateDto> AddCandidateAsync(int userId, int draftId, UpsertCandidateRequest request);
    Task<DraftCandidateDto> UpdateCandidateAsync(int userId, int draftId, int candidateId, UpsertCandidateRequest request);
    Task DeleteCandidateAsync(int userId, int draftId, int candidateId);
    Task<List<DraftCandidateDto>> AddFriendsAsync(int userId, int draftId, int candidateId, int count);

    Task<LoginResponse> LaunchTeamAsync(int userId, int draftId, string? nomeGiocatore = null, string? soprannome = null);

    Task<DraftPreviewDto?> GetByShareCodeAsync(string shareCode);
    Task<TeamDraftDto> JoinByShareCodeAsync(int userId, string shareCode);
}

public class TeamDraftService : ITeamDraftService
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<TeamDraftService> _logger;

    public TeamDraftService(ApplicationDbContext context, IConfiguration configuration, ILogger<TeamDraftService> logger)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<List<TeamDraftDto>> GetMyDraftsAsync(int userId)
    {
        var drafts = await _context.DraftCollaborators
            .Where(c => c.UserId == userId)
            .Include(c => c.TeamDraft).ThenInclude(d => d.Candidates)
            .Include(c => c.TeamDraft).ThenInclude(d => d.Collaborators).ThenInclude(cc => cc.User)
            .OrderByDescending(c => c.TeamDraft.UpdatedAt)
            .Select(c => c.TeamDraft)
            .ToListAsync();

        return drafts.Select(d => Map(d, userId)).ToList();
    }

    public async Task<TeamDraftDto> GetDraftAsync(int userId, int draftId)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);
        return Map(draft, userId);
    }

    public async Task<TeamDraftDto> CreateDraftAsync(int userId, UpsertDraftRequest request)
    {
        var draft = new TeamDraft
        {
            UserId = userId,
            NomeTeam = request.NomeTeam,
            Formato = ClubService.ParseFormat(request.Formato),
            PartitePerStagione = request.PartitePerStagione,
            GettoniPerGiocatore = request.GettoniPerGiocatore,
            UseGettoni = request.UseGettoni,
            ShareCode = await GenerateUniqueShareCodeAsync(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.TeamDrafts.Add(draft);
        await _context.SaveChangesAsync();

        _context.DraftCollaborators.Add(new DraftCollaborator
        {
            TeamDraftId = draft.Id,
            UserId = userId,
            IsOwner = true,
            JoinedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        // Ricarico per popolare collaborators
        var full = await _context.TeamDrafts
            .Include(d => d.Candidates)
            .Include(d => d.Collaborators).ThenInclude(c => c.User)
            .FirstAsync(d => d.Id == draft.Id);

        return Map(full, userId);
    }

    public async Task<TeamDraftDto> UpdateDraftAsync(int userId, int draftId, UpsertDraftRequest request)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);

        draft.NomeTeam = request.NomeTeam;
        draft.Formato = ClubService.ParseFormat(request.Formato);
        draft.PartitePerStagione = request.PartitePerStagione;
        draft.GettoniPerGiocatore = request.GettoniPerGiocatore;
        draft.UseGettoni = request.UseGettoni;
        draft.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Map(draft, userId);
    }

    public async Task DeleteDraftAsync(int userId, int draftId)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: true);
        _context.TeamDrafts.Remove(draft);
        await _context.SaveChangesAsync();
    }

    public async Task<DraftCandidateDto> AddCandidateAsync(int userId, int draftId, UpsertCandidateRequest request)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);

        var candidate = new DraftCandidate
        {
            TeamDraftId = draft.Id,
            Nome = request.Nome,
            Soprannome = request.Soprannome,
            Posizione = ParsePosition(request.Posizione),
            Stato = ParseStato(request.Stato),
            Bravura = request.Bravura,
            Affidabilita = request.Affidabilita,
            Tesserato = request.Tesserato,
            Note = request.Note,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.DraftCandidates.Add(candidate);
        draft.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Map(candidate);
    }

    public async Task<DraftCandidateDto> UpdateCandidateAsync(int userId, int draftId, int candidateId, UpsertCandidateRequest request)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);
        var candidate = draft.Candidates.FirstOrDefault(c => c.Id == candidateId)
            ?? throw new NotFoundException("Candidate", candidateId);

        candidate.Nome = request.Nome;
        candidate.Soprannome = request.Soprannome;
        candidate.Posizione = ParsePosition(request.Posizione);
        candidate.Stato = ParseStato(request.Stato);
        candidate.Bravura = request.Bravura;
        candidate.Affidabilita = request.Affidabilita;
        candidate.Tesserato = request.Tesserato;
        candidate.Note = request.Note;
        candidate.UpdatedAt = DateTime.UtcNow;
        draft.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Map(candidate);
    }

    public async Task DeleteCandidateAsync(int userId, int draftId, int candidateId)
    {
        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);
        var candidate = draft.Candidates.FirstOrDefault(c => c.Id == candidateId)
            ?? throw new NotFoundException("Candidate", candidateId);

        _context.DraftCandidates.Remove(candidate);
        draft.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
    }

    public async Task<List<DraftCandidateDto>> AddFriendsAsync(int userId, int draftId, int candidateId, int count)
    {
        if (count < 1 || count > 6)
            throw new BadRequestException("Numero amici fuori range (1-6)");

        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: false);
        var parent = draft.Candidates.FirstOrDefault(c => c.Id == candidateId)
            ?? throw new NotFoundException("Candidate", candidateId);

        if (parent.IsFriend)
            throw new BadRequestException("Non puoi aggiungere amici a un altro amico");

        var baseName = parent.Nome.Trim();
        var existingNames = draft.Candidates.Select(c => c.Nome).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var created = new List<DraftCandidate>();

        var n = 1;
        for (var i = 0; i < count; i++)
        {
            string name;
            do
            {
                name = $"{baseName} {n}";
                n++;
            } while (existingNames.Contains(name));

            existingNames.Add(name);

            var friend = new DraftCandidate
            {
                TeamDraftId = draft.Id,
                Nome = name,
                Soprannome = null,
                Posizione = parent.Posizione,
                Stato = DraftStatus.DaSentire,
                Bravura = 1,
                Affidabilita = 1,
                Tesserato = false,
                IsFriend = true,
                Note = $"Amico di {baseName}",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.DraftCandidates.Add(friend);
            created.Add(friend);
        }

        draft.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return created.Select(Map).ToList();
    }

    public async Task<LoginResponse> LaunchTeamAsync(int userId, int draftId, string? nomeGiocatore = null, string? soprannome = null)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new NotFoundException("Utente", userId);

        var draft = await LoadDraftWithChecksAsync(userId, draftId, ownerOnly: true);

        var confermati = draft.Candidates.Where(c => c.Stato == DraftStatus.Confermato).ToList();
        if (confermati.Count == 0)
            throw new BusinessException("Servono almeno 1 candidato Confermato per lanciare la squadra");

        await using var tx = await _context.Database.BeginTransactionAsync();

        // Ogni squadra nasce dentro una societa': se domani serve anche la squadra a 7,
        // si aggiunge alla stessa societa' e condivide l'anagrafica.
        var club = new Club
        {
            Nome = draft.NomeTeam,
            InviteCode = await GenerateUniqueClubCodeAsync(),
            CreatedAt = DateTime.UtcNow
        };
        _context.Clubs.Add(club);
        await _context.SaveChangesAsync();

        var team = new Team
        {
            ClubId = club.Id,
            Nome = draft.NomeTeam,
            Formato = draft.Formato,
            PartitePerStagione = draft.PartitePerStagione,
            GettoniPerGiocatore = draft.GettoniPerGiocatore,
            UseGettoni = draft.UseGettoni,
            InviteCode = GenerateInviteCode(),
            CreatedAt = DateTime.UtcNow
        };
        team.ApplyFormatDefaults();
        _context.Teams.Add(team);
        await _context.SaveChangesAsync();

        var adminNome = !string.IsNullOrWhiteSpace(nomeGiocatore) ? nomeGiocatore : user.Email.Split('@')[0];

        var adminMember = new ClubMember
        {
            ClubId = club.Id,
            UserId = userId,
            Nome = adminNome,
            Soprannome = soprannome,
            CreatedAt = DateTime.UtcNow
        };
        _context.ClubMembers.Add(adminMember);

        // I collaboratori (non-owner) che hanno co-pianificato entrano nel team come giocatori
        var collaborators = draft.Collaborators.Where(c => !c.IsOwner && c.UserId != userId).ToList();
        var collabMembers = collaborators.Select(collab => new ClubMember
        {
            ClubId = club.Id,
            UserId = collab.UserId,
            Nome = collab.User?.Email.Split('@')[0] ?? $"Utente{collab.UserId}",
            CreatedAt = DateTime.UtcNow
        }).ToList();
        _context.ClubMembers.AddRange(collabMembers);
        await _context.SaveChangesAsync();

        var adminPlayer = new Player
        {
            TeamId = team.Id,
            UserId = userId,
            ClubMemberId = adminMember.Id,
            Nome = adminMember.Nome,
            Soprannome = adminMember.Soprannome,
            Ruolo = UserRole.Admin,
            GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        _context.Players.Add(adminPlayer);

        foreach (var member in collabMembers)
        {
            _context.Players.Add(new Player
            {
                TeamId = team.Id,
                UserId = member.UserId!.Value,
                ClubMemberId = member.Id,
                Nome = member.Nome,
                Ruolo = UserRole.User,
                GettoniTotali = team.UseGettoni ? team.GettoniPerGiocatore : 0,
                GettoniConsumati = 0,
                CreatedAt = DateTime.UtcNow
            });
        }

        foreach (var c in confermati)
        {
            _context.PendingPlayers.Add(new PendingPlayer
            {
                TeamId = team.Id,
                Nome = c.Nome,
                Soprannome = c.Soprannome,
                // Se il formato e' stato cambiato dopo aver schedato i candidati,
                // i ruoli non piu' previsti vengono scartati invece di restare incoerenti
                Posizione = c.Posizione.HasValue && TeamFormats.SupportsPosition(team.Formato, c.Posizione.Value)
                    ? c.Posizione
                    : null,
                Bravura = c.Bravura,
                Affidabilita = c.Affidabilita,
                Tesserato = c.Tesserato,
                Note = c.Note,
                CreatedAt = DateTime.UtcNow
            });
        }

        _context.TeamDrafts.Remove(draft);
        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        _logger.LogInformation("Team lanciato da draft: TeamId={TeamId}, DraftId={DraftId}, UserId={UserId}, PendingPlayers={Count}",
            team.Id, draftId, userId, confermati.Count);

        var accessToken = GenerateAccessToken(user, adminPlayer);
        var refreshToken = await GenerateRefreshTokenAsync(userId);
        var expirationMinutes = int.Parse(_configuration["Jwt:AccessTokenExpirationMinutes"] ?? "60");

        return new LoginResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken.Token,
            AccessTokenExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            Player = new PlayerInfo
            {
                Id = adminPlayer.Id,
                UserId = user.Id,
                TeamId = adminPlayer.TeamId,
                Email = user.Email,
                Nome = adminPlayer.Nome,
                Soprannome = adminPlayer.Soprannome,
                Ruolo = adminPlayer.Ruolo.ToString()
            }
        };
    }

    public async Task<DraftPreviewDto?> GetByShareCodeAsync(string shareCode)
    {
        var draft = await _context.TeamDrafts
            .Include(d => d.User)
            .Include(d => d.Candidates)
            .Include(d => d.Collaborators)
            .FirstOrDefaultAsync(d => d.ShareCode == shareCode);

        if (draft == null) return null;

        return new DraftPreviewDto
        {
            Id = draft.Id,
            NomeTeam = draft.NomeTeam,
            OwnerEmail = MaskEmail(draft.User.Email),
            CandidatesCount = draft.Candidates.Count,
            CollaboratorsCount = draft.Collaborators.Count
        };
    }

    public async Task<TeamDraftDto> JoinByShareCodeAsync(int userId, string shareCode)
    {
        var draft = await _context.TeamDrafts
            .Include(d => d.Candidates)
            .Include(d => d.Collaborators).ThenInclude(c => c.User)
            .FirstOrDefaultAsync(d => d.ShareCode == shareCode)
            ?? throw new NotFoundException("Codice draft non valido");

        var existing = draft.Collaborators.FirstOrDefault(c => c.UserId == userId);
        if (existing == null)
        {
            _context.DraftCollaborators.Add(new DraftCollaborator
            {
                TeamDraftId = draft.Id,
                UserId = userId,
                IsOwner = false,
                JoinedAt = DateTime.UtcNow
            });
            draft.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            _logger.LogInformation("User {UserId} joined draft {DraftId} via share code", userId, draft.Id);

            // Ricarico per popolare collaborators
            draft = await _context.TeamDrafts
                .Include(d => d.Candidates)
                .Include(d => d.Collaborators).ThenInclude(c => c.User)
                .FirstAsync(d => d.Id == draft.Id);
        }

        return Map(draft, userId);
    }

    private async Task<TeamDraft> LoadDraftWithChecksAsync(int userId, int draftId, bool ownerOnly)
    {
        var draft = await _context.TeamDrafts
            .Include(d => d.Candidates)
            .Include(d => d.Collaborators).ThenInclude(c => c.User)
            .FirstOrDefaultAsync(d => d.Id == draftId)
            ?? throw new NotFoundException("Draft", draftId);

        var membership = draft.Collaborators.FirstOrDefault(c => c.UserId == userId);
        if (membership == null)
            throw new UnauthorizedException("Non hai accesso a questo draft");

        if (ownerOnly && !membership.IsOwner)
            throw new UnauthorizedException("Solo l'owner può eseguire questa operazione");

        return draft;
    }

    private async Task<string> GenerateUniqueShareCodeAsync()
    {
        for (int attempt = 0; attempt < 8; attempt++)
        {
            var code = GenerateInviteCode();
            var taken = await _context.TeamDrafts.AnyAsync(d => d.ShareCode == code);
            if (!taken) return code;
        }
        throw new BusinessException("Impossibile generare un codice univoco, riprova");
    }

    private static PlayerPosition? ParsePosition(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        if (Enum.TryParse<PlayerPosition>(value, true, out var pos)) return pos;
        throw new BadRequestException($"Posizione non valida: {value}");
    }

    private static DraftStatus ParseStato(string value)
    {
        if (Enum.TryParse<DraftStatus>(value, true, out var st)) return st;
        throw new BadRequestException($"Stato non valido: {value}");
    }

    private static string MaskEmail(string email)
    {
        var at = email.IndexOf('@');
        if (at <= 0) return "***";
        var local = email[..at];
        var domain = email[at..];
        var shown = local.Length <= 2 ? local[..1] : local[..2];
        return $"{shown}{new string('*', 3)}{domain}";
    }

    private static TeamDraftDto Map(TeamDraft draft, int currentUserId)
    {
        var me = draft.Collaborators.FirstOrDefault(c => c.UserId == currentUserId);
        var isOwner = me?.IsOwner ?? false;
        return new TeamDraftDto
        {
            Id = draft.Id,
            NomeTeam = draft.NomeTeam,
            Formato = draft.Formato.ToString(),
            FormatoLabel = TeamFormats.Label(draft.Formato),
            PartitePerStagione = draft.PartitePerStagione,
            GettoniPerGiocatore = draft.GettoniPerGiocatore,
            UseGettoni = draft.UseGettoni,
            // Lo ShareCode (= potere di invitare) è visibile solo all'owner
            ShareCode = isOwner ? (draft.ShareCode ?? string.Empty) : string.Empty,
            IsOwner = isOwner,
            OwnerUserId = draft.UserId,
            CreatedAt = draft.CreatedAt,
            UpdatedAt = draft.UpdatedAt,
            Candidates = draft.Candidates.OrderBy(c => c.Id).Select(Map).ToList(),
            Collaborators = draft.Collaborators
                .OrderByDescending(c => c.IsOwner)
                .ThenBy(c => c.JoinedAt)
                .Select(c => new DraftCollaboratorDto
                {
                    UserId = c.UserId,
                    Email = c.User?.Email ?? string.Empty,
                    IsOwner = c.IsOwner,
                    JoinedAt = c.JoinedAt
                }).ToList()
        };
    }

    private static DraftCandidateDto Map(DraftCandidate c) => new()
    {
        Id = c.Id,
        Nome = c.Nome,
        Soprannome = c.Soprannome,
        Posizione = c.Posizione?.ToString(),
        Stato = c.Stato.ToString(),
        Bravura = c.Bravura,
        Affidabilita = c.Affidabilita,
        Tesserato = c.Tesserato,
        IsFriend = c.IsFriend,
        Note = c.Note
    };

    private string GenerateAccessToken(User user, Player player)
    {
        var key = Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!);
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
            Issuer = _configuration["Jwt:Issuer"],
            Audience = _configuration["Jwt:Audience"],
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                SecurityAlgorithms.HmacSha256Signature)
        };

        var handler = new JwtSecurityTokenHandler();
        return handler.WriteToken(handler.CreateToken(tokenDescriptor));
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

    private async Task<string> GenerateUniqueClubCodeAsync()
    {
        for (var i = 0; i < 10; i++)
        {
            var code = GenerateInviteCode();
            if (!await _context.Clubs.AnyAsync(c => c.InviteCode == code)) return code;
        }
        throw new BusinessException("Impossibile generare un codice invito, riprova");
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
}
