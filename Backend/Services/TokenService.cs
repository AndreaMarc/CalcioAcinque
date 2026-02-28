using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Tokens;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface ITokenService
{
    Task<List<PlayerTokenSummaryDto>> GetTeamTokenSummaryAsync(int teamId);
    Task<List<TokenTransactionDto>> GetPlayerTransactionsAsync(int playerId, int teamId);
    Task<TokenTransactionDto> ManualAdjustAsync(int playerId, ManualTokenDto dto, int adminPlayerId, int teamId);
}

public class TokenService : ITokenService
{
    private readonly ApplicationDbContext _context;
    public TokenService(ApplicationDbContext context) { _context = context; }

    public async Task<List<PlayerTokenSummaryDto>> GetTeamTokenSummaryAsync(int teamId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team != null && !team.UseGettoni) return new List<PlayerTokenSummaryDto>();
        var players = await _context.Players.Where(p => p.TeamId == teamId).OrderBy(p => p.Nome).ToListAsync();
        return players.Select(p => new PlayerTokenSummaryDto
        {
            PlayerId = p.Id, Nome = p.Nome, Soprannome = p.Soprannome,
            GettoniTotali = p.GettoniTotali, GettoniConsumati = p.GettoniConsumati, GettoniRimanenti = p.GettoniRimanenti
        }).ToList();
    }

    public async Task<List<TokenTransactionDto>> GetPlayerTransactionsAsync(int playerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var transactions = await _context.TokenTransactions
            .Include(t => t.Player).Include(t => t.Match).Include(t => t.Admin)
            .Where(t => t.PlayerId == playerId).OrderByDescending(t => t.Timestamp).ToListAsync();
        return transactions.Select(MapToDto).ToList();
    }

    public async Task<TokenTransactionDto> ManualAdjustAsync(int playerId, ManualTokenDto dto, int adminPlayerId, int teamId)
    {
        if (string.IsNullOrWhiteSpace(dto.Motivazione))
            throw new BusinessException("La motivazione e' obbligatoria per le operazioni manuali sui gettoni");
        if (dto.Quantita == 0) throw new BadRequestException("La quantita' non puo' essere zero");

        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var team = await _context.Teams.FindAsync(teamId);
        if (team != null && !team.UseGettoni)
            throw new BusinessException("Il sistema gettoni e' disabilitato per questo team");

        var tipo = dto.Quantita > 0 ? TipoTransazione.AggiuntaManuale : TipoTransazione.RimozioneManuale;

        if (dto.Quantita > 0) player.GettoniTotali += dto.Quantita;
        else player.GettoniConsumati += Math.Abs(dto.Quantita);

        var transaction = new TokenTransaction
        {
            PlayerId = playerId, MatchId = dto.MatchId, Tipo = tipo, Motivazione = dto.Motivazione,
            Quantita = dto.Quantita, AdminId = adminPlayerId, Timestamp = DateTime.UtcNow
        };
        _context.TokenTransactions.Add(transaction);
        await _context.SaveChangesAsync();

        // Reload for DTO
        await _context.Entry(transaction).Reference(t => t.Player).LoadAsync();
        await _context.Entry(transaction).Reference(t => t.Admin).LoadAsync();
        return MapToDto(transaction);
    }

    private static TokenTransactionDto MapToDto(TokenTransaction t) => new()
    {
        Id = t.Id, PlayerId = t.PlayerId, NomeGiocatore = t.Player?.Nome ?? "",
        MatchId = t.MatchId, NumeroGiornata = t.Match?.NumeroGiornata,
        Tipo = t.Tipo.ToString(), Motivazione = t.Motivazione, Quantita = t.Quantita,
        AdminNome = t.Admin?.Nome ?? "", Timestamp = t.Timestamp
    };
}
