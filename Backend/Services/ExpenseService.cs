using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Cassa;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IExpenseService
{
    Task<List<TeamExpenseDto>> GetByTeamAsync(int teamId, int? seasonId);
    Task<TeamExpenseDto> CreateAsync(int teamId, UpsertExpenseDto dto, int adminPlayerId);
    Task<TeamExpenseDto> UpdateAsync(int expenseId, int teamId, UpsertExpenseDto dto);
    Task DeleteAsync(int expenseId, int teamId);
    Task<CassaSummaryDto> GetCassaAsync(int teamId, int? seasonId);
}

/// <summary>Uscite di cassa e cruscotto del cassiere.</summary>
public class ExpenseService : IExpenseService
{
    private readonly ApplicationDbContext _context;
    private readonly ISeasonService _seasons;

    public ExpenseService(ApplicationDbContext context, ISeasonService seasons)
    {
        _context = context;
        _seasons = seasons;
    }

    public async Task<List<TeamExpenseDto>> GetByTeamAsync(int teamId, int? seasonId)
    {
        var season = await ResolveSeasonAsync(teamId, seasonId);
        var query = _context.TeamExpenses.Where(e => e.TeamId == teamId);
        if (season != null) query = query.Where(e => e.SeasonId == season.Id);
        var list = await query.OrderByDescending(e => e.Data).ThenByDescending(e => e.Id).ToListAsync();
        return list.Select(MapToDto).ToList();
    }

    public async Task<TeamExpenseDto> CreateAsync(int teamId, UpsertExpenseDto dto, int adminPlayerId)
    {
        var team = await _context.Teams.FindAsync(teamId) ?? throw new NotFoundException("Team", teamId);
        var season = await _seasons.GetOrCreateCorrenteAsync(teamId);
        var adminNome = await _context.Players.Where(p => p.Id == adminPlayerId).Select(p => p.Nome).FirstOrDefaultAsync();

        if (dto.MatchId.HasValue &&
            !await _context.Matches.AnyAsync(m => m.Id == dto.MatchId.Value && m.TeamId == teamId))
            throw new NotFoundException("Partita", dto.MatchId.Value);

        var expense = new TeamExpense
        {
            TeamId = team.Id,
            SeasonId = season.Id,
            MatchId = dto.MatchId,
            Categoria = ParseCategoria(dto.Categoria),
            Descrizione = dto.Descrizione.Trim(),
            Importo = dto.Importo,
            Data = (dto.Data ?? DateTime.UtcNow).Date,
            Note = string.IsNullOrWhiteSpace(dto.Note) ? null : dto.Note.Trim(),
            AdminId = adminPlayerId,
            AdminNome = adminNome,
            CreatedAt = DateTime.UtcNow
        };
        _context.TeamExpenses.Add(expense);
        await _context.SaveChangesAsync();
        return MapToDto(expense);
    }

    public async Task<TeamExpenseDto> UpdateAsync(int expenseId, int teamId, UpsertExpenseDto dto)
    {
        var expense = await _context.TeamExpenses.FirstOrDefaultAsync(e => e.Id == expenseId && e.TeamId == teamId)
            ?? throw new NotFoundException("Uscita", expenseId);

        expense.Categoria = ParseCategoria(dto.Categoria);
        expense.Descrizione = dto.Descrizione.Trim();
        expense.Importo = dto.Importo;
        if (dto.Data.HasValue) expense.Data = dto.Data.Value.Date;
        expense.Note = string.IsNullOrWhiteSpace(dto.Note) ? null : dto.Note.Trim();
        await _context.SaveChangesAsync();
        return MapToDto(expense);
    }

    public async Task DeleteAsync(int expenseId, int teamId)
    {
        var expense = await _context.TeamExpenses.FirstOrDefaultAsync(e => e.Id == expenseId && e.TeamId == teamId)
            ?? throw new NotFoundException("Uscita", expenseId);
        _context.TeamExpenses.Remove(expense);
        await _context.SaveChangesAsync();
    }

    public async Task<CassaSummaryDto> GetCassaAsync(int teamId, int? seasonId)
    {
        var team = await _context.Teams.FindAsync(teamId) ?? throw new NotFoundException("Team", teamId);
        var season = await ResolveSeasonAsync(teamId, seasonId);

        var paymentsQuery = _context.PlayerPayments.Where(p => p.TeamId == teamId);
        var expensesQuery = _context.TeamExpenses.Where(e => e.TeamId == teamId);
        var matchesQuery = _context.Matches.Where(m => m.TeamId == teamId && m.Stato == StatoPartita.Conclusa);
        if (season != null)
        {
            paymentsQuery = paymentsQuery.Where(p => p.SeasonId == season.Id);
            expensesQuery = expensesQuery.Where(e => e.SeasonId == season.Id);
            matchesQuery = matchesQuery.Where(m => m.SeasonId == season.Id);
        }

        var payments = await paymentsQuery.ToListAsync();
        var expenses = await expensesQuery.ToListAsync();
        var matches = await matchesQuery.OrderByDescending(m => m.Data).ToListAsync();

        var incassate = payments.Where(p => p.Pagato).Sum(p => p.Importo);
        var uscite = expenses.Sum(e => e.Importo);

        // Partite concluse senza nessun addebito: dimenticarne una era invisibile
        var matchIdsConIncasso = payments.Where(p => p.MatchId != null).Select(p => p.MatchId!.Value).ToHashSet();
        var senzaIncasso = matches.Where(m => !matchIdsConIncasso.Contains(m.Id)).ToList();
        var nonIncassate = new List<PartitaNonIncassataDto>();
        if (senzaIncasso.Count > 0)
        {
            var ids = senzaIncasso.Select(m => m.Id).ToList();
            var presenze = await _context.MatchAttendances
                .Include(a => a.Player)
                .Where(a => ids.Contains(a.MatchId) && a.Presente)
                .ToListAsync();
            foreach (var m in senzaIncasso)
            {
                var presenti = presenze.Where(a => a.MatchId == m.Id).ToList();
                nonIncassate.Add(new PartitaNonIncassataDto
                {
                    MatchId = m.Id,
                    NumeroGiornata = m.NumeroGiornata,
                    Data = m.Data,
                    Titolo = m.Titolo,
                    Presenti = presenti.Count,
                    PresentiAPartita = presenti.Count(a =>
                        RegimiPagamento.Effettivo(a.Player.RegimePagamento, team.RegimePagamentoDefault) == RegimePagamento.APartita)
                });
            }
        }

        // Arretrati per giocatore: il nome e' quello congelato sulla voce, il
        // soprannome (se c'e' ancora la tessera) serve alla lista
        var soprannomi = await _context.Players
            .Where(p => p.TeamId == teamId)
            .ToDictionaryAsync(p => p.Id, p => p.Soprannome);
        var arretrati = payments
            .Where(p => !p.Pagato && p.PlayerId != null)
            .GroupBy(p => p.PlayerId!.Value)
            .Select(g => new ArretratoDto
            {
                PlayerId = g.Key,
                Nome = g.OrderByDescending(p => p.CreatedAt).First().NomeGiocatore,
                Soprannome = soprannomi.GetValueOrDefault(g.Key),
                Importo = g.Sum(p => p.Importo),
                Voci = g.Count()
            })
            .OrderByDescending(a => a.Importo)
            .ToList();

        return new CassaSummaryDto
        {
            SeasonId = season?.Id,
            SeasonNome = season?.Nome,
            EntrateAttese = payments.Sum(p => p.Importo),
            EntrateIncassate = incassate,
            InVerifica = payments.Where(p => !p.Pagato && p.DichiaratoPagatoAt != null).Sum(p => p.Importo),
            Uscite = uscite,
            Saldo = incassate - uscite,
            PartiteNonIncassate = nonIncassate,
            Arretrati = arretrati,
            UscitePerCategoria = expenses
                .GroupBy(e => e.Categoria)
                .Select(g => new UscitaCategoriaDto
                {
                    Categoria = g.Key.ToString(),
                    Label = CategorieSpesa.Label(g.Key),
                    Importo = g.Sum(e => e.Importo)
                })
                .OrderByDescending(u => u.Importo)
                .ToList()
        };
    }

    private async Task<Season?> ResolveSeasonAsync(int teamId, int? seasonId)
    {
        if (seasonId.HasValue)
            return await _context.Seasons.FirstOrDefaultAsync(s => s.Id == seasonId.Value && s.TeamId == teamId)
                   ?? throw new NotFoundException("Stagione", seasonId.Value);
        return await _seasons.GetCorrenteAsync(teamId);
    }

    public static CategoriaSpesa ParseCategoria(string? value) =>
        Enum.TryParse<CategoriaSpesa>(value, true, out var c) ? c : CategoriaSpesa.Altro;

    public static TeamExpenseDto MapToDto(TeamExpense e) => new()
    {
        Id = e.Id,
        TeamId = e.TeamId,
        SeasonId = e.SeasonId,
        MatchId = e.MatchId,
        Categoria = e.Categoria.ToString(),
        CategoriaLabel = CategorieSpesa.Label(e.Categoria),
        Descrizione = e.Descrizione,
        Importo = e.Importo,
        Data = e.Data,
        Note = e.Note,
        AdminNome = e.AdminNome,
        CreatedAt = e.CreatedAt
    };
}
