using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;

namespace CalcioAcinque.Backend.Services;

public interface IPaymentService
{
    Task<List<PlayerPaymentDto>> GetByTeamAsync(int teamId);
    Task<List<PlayerPaymentDto>> GetByPlayerAsync(int playerId, int teamId);
    Task<PlayerPaymentDto> CreateAsync(int playerId, CreatePaymentDto dto, int adminPlayerId, int teamId);
    Task<PlayerPaymentDto> UpdateAsync(int paymentId, UpdatePaymentDto dto, int teamId);
}

public class PaymentService : IPaymentService
{
    private readonly ApplicationDbContext _context;
    public PaymentService(ApplicationDbContext context) { _context = context; }

    public async Task<List<PlayerPaymentDto>> GetByTeamAsync(int teamId)
    {
        var payments = await _context.PlayerPayments.Include(p => p.Player).Include(p => p.Admin)
            .Where(p => p.Player.TeamId == teamId).OrderByDescending(p => p.DataPagamento).ToListAsync();
        return payments.Select(MapToDto).ToList();
    }

    public async Task<List<PlayerPaymentDto>> GetByPlayerAsync(int playerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var payments = await _context.PlayerPayments.Include(p => p.Player).Include(p => p.Admin)
            .Where(p => p.PlayerId == playerId).OrderByDescending(p => p.DataPagamento).ToListAsync();
        return payments.Select(MapToDto).ToList();
    }

    public async Task<PlayerPaymentDto> CreateAsync(int playerId, CreatePaymentDto dto, int adminPlayerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var payment = new PlayerPayment
        {
            PlayerId = playerId, Descrizione = dto.Descrizione, Importo = dto.Importo,
            DataPagamento = dto.DataPagamento, Pagato = dto.Pagato, Note = dto.Note,
            AdminId = adminPlayerId, CreatedAt = DateTime.UtcNow
        };
        _context.PlayerPayments.Add(payment);
        await _context.SaveChangesAsync();

        await _context.Entry(payment).Reference(p => p.Player).LoadAsync();
        await _context.Entry(payment).Reference(p => p.Admin).LoadAsync();
        return MapToDto(payment);
    }

    public async Task<PlayerPaymentDto> UpdateAsync(int paymentId, UpdatePaymentDto dto, int teamId)
    {
        var payment = await _context.PlayerPayments.Include(p => p.Player).Include(p => p.Admin)
            .FirstOrDefaultAsync(p => p.Id == paymentId);
        if (payment == null) throw new NotFoundException("Pagamento", paymentId);
        if (payment.Player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");
        if (dto.Descrizione != null) payment.Descrizione = dto.Descrizione;
        if (dto.Importo.HasValue) payment.Importo = dto.Importo.Value;
        if (dto.DataPagamento.HasValue) payment.DataPagamento = dto.DataPagamento.Value;
        if (dto.Pagato.HasValue) payment.Pagato = dto.Pagato.Value;
        if (dto.Note != null) payment.Note = dto.Note;
        await _context.SaveChangesAsync();
        return MapToDto(payment);
    }

    private static PlayerPaymentDto MapToDto(PlayerPayment p) => new()
    {
        Id = p.Id, PlayerId = p.PlayerId, NomeGiocatore = p.Player.Nome, Descrizione = p.Descrizione,
        Importo = p.Importo, DataPagamento = p.DataPagamento, Pagato = p.Pagato, Note = p.Note,
        AdminNome = p.Admin.Nome, CreatedAt = p.CreatedAt
    };
}
