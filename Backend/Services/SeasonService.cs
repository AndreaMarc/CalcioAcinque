using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Seasons;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface ISeasonService
{
    Task<List<SeasonDto>> GetByTeamAsync(int teamId);

    /// <summary>Stagione aperta, oppure null. Non scrive: usarla nei percorsi di lettura.</summary>
    Task<Season?> GetCorrenteAsync(int teamId);

    /// <summary>
    /// La stagione aperta della squadra, creandola se manca. Da usare nei percorsi
    /// di scrittura, cosi' non esiste uno stato "squadra senza stagione".
    /// </summary>
    Task<Season> GetOrCreateCorrenteAsync(int teamId);

    Task<CloseSeasonResultDto> CloseAsync(int teamId, CloseSeasonDto dto, int adminPlayerId);
}

public class SeasonService : ISeasonService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<SeasonService> _logger;

    public SeasonService(ApplicationDbContext context, ILogger<SeasonService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<List<SeasonDto>> GetByTeamAsync(int teamId)
    {
        var seasons = await _context.Seasons
            .Where(s => s.TeamId == teamId)
            .OrderByDescending(s => s.DataInizio)
            .ToListAsync();

        if (seasons.Count == 0)
        {
            await GetOrCreateCorrenteAsync(teamId);
            seasons = await _context.Seasons
                .Where(s => s.TeamId == teamId)
                .OrderByDescending(s => s.DataInizio)
                .ToListAsync();
        }

        var ids = seasons.Select(s => s.Id).ToList();

        var partite = await _context.Matches
            .Where(m => m.SeasonId != null && ids.Contains(m.SeasonId.Value))
            .GroupBy(m => m.SeasonId!.Value)
            .Select(g => new { SeasonId = g.Key, N = g.Count() })
            .ToDictionaryAsync(x => x.SeasonId, x => x.N);

        var conti = await _context.PlayerPayments
            .Where(p => p.SeasonId != null && ids.Contains(p.SeasonId.Value))
            .GroupBy(p => p.SeasonId!.Value)
            .Select(g => new
            {
                SeasonId = g.Key,
                Incassato = g.Where(x => x.Pagato).Sum(x => x.Importo),
                DaIncassare = g.Where(x => !x.Pagato).Sum(x => x.Importo)
            })
            .ToDictionaryAsync(x => x.SeasonId, x => x);

        return seasons.Select(s => new SeasonDto
        {
            Id = s.Id,
            TeamId = s.TeamId,
            Nome = s.Nome,
            DataInizio = s.DataInizio,
            DataFine = s.DataFine,
            Chiusa = s.Chiusa,
            Note = s.Note,
            Partite = partite.TryGetValue(s.Id, out var n) ? n : 0,
            Incassato = conti.TryGetValue(s.Id, out var c) ? c.Incassato : 0m,
            DaIncassare = conti.TryGetValue(s.Id, out var c2) ? c2.DaIncassare : 0m
        }).ToList();
    }

    public Task<Season?> GetCorrenteAsync(int teamId) => _context.Seasons
        .Where(s => s.TeamId == teamId && !s.Chiusa)
        .OrderByDescending(s => s.DataInizio)
        .FirstOrDefaultAsync();

    public async Task<Season> GetOrCreateCorrenteAsync(int teamId)
    {
        var aperta = await GetCorrenteAsync(teamId);
        if (aperta != null) return aperta;

        var season = new Season
        {
            TeamId = teamId,
            Nome = await NomeLiberoAsync(teamId, NomeStagione(DateTime.UtcNow)),
            DataInizio = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };
        _context.Seasons.Add(season);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Creata stagione {Nome} per la squadra {TeamId}", season.Nome, teamId);
        return season;
    }

    /// <summary>
    /// Chiude la stagione e ne apre una nuova: le partite e i conti della vecchia
    /// restano consultabili, i contatori dei giocatori ripartono da zero.
    /// </summary>
    public async Task<CloseSeasonResultDto> CloseAsync(int teamId, CloseSeasonDto dto, int adminPlayerId)
    {
        var team = await _context.Teams.FindAsync(teamId)
            ?? throw new NotFoundException("Team", teamId);

        var corrente = await GetOrCreateCorrenteAsync(teamId);

        var arretrati = await _context.PlayerPayments
            .Where(p => p.TeamId == teamId && !p.Pagato && p.SeasonId == corrente.Id)
            .SumAsync(p => (decimal?)p.Importo) ?? 0m;

        // Chiudere lasciando conti aperti e' quasi sempre un errore: si blocca,
        // ma l'admin puo' forzare se ha deciso di condonarli.
        if (arretrati > 0 && !dto.IgnoraArretrati)
            throw new BusinessException(
                $"Ci sono ancora {PaymentService.Euro(arretrati)} da incassare in questa stagione. " +
                "Saldali, oppure conferma di voler chiudere comunque.");

        // Chiudendo a meta' stagione il nome calcolato sarebbe lo stesso di quella
        // appena chiusa: due voci identiche nell'archivio non si distinguono.
        var nomeNuova = string.IsNullOrWhiteSpace(dto.NomeNuovaStagione)
            ? await NomeLiberoAsync(teamId, NomeStagione(DateTime.UtcNow))
            : dto.NomeNuovaStagione!.Trim();

        if (!string.IsNullOrWhiteSpace(dto.NomeNuovaStagione)
            && await _context.Seasons.AnyAsync(s => s.TeamId == teamId && s.Nome == nomeNuova))
            throw new BusinessException($"Esiste già una stagione chiamata {nomeNuova}");

        await using var tx = await _context.Database.BeginTransactionAsync();

        corrente.Chiusa = true;
        corrente.DataFine = DateTime.UtcNow;
        if (!string.IsNullOrWhiteSpace(dto.Note)) corrente.Note = dto.Note;

        var nuova = new Season
        {
            TeamId = teamId,
            Nome = nomeNuova,
            DataInizio = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };
        _context.Seasons.Add(nuova);
        await _context.SaveChangesAsync();

        // Reset dei contatori. Il ricarico dei gettoni viene registrato come
        // transazione, altrimenti lo storico mostrerebbe consumi senza ricariche.
        var players = await _context.Players.Where(p => p.TeamId == teamId).ToListAsync();
        var adminNome = players.FirstOrDefault(p => p.Id == adminPlayerId)?.Nome ?? "";
        var result = new CloseSeasonResultDto
        {
            StagioneChiusa = corrente.Nome,
            StagioneNuova = nuova.Nome,
            GiocatoriAzzerati = players.Count,
            ArretratiLasciatiAperti = arretrati
        };

        foreach (var player in players)
        {
            var gettoniNuovi = team.UseGettoni ? team.GettoniPerGiocatore : 0;

            if (team.UseGettoni)
            {
                _context.TokenTransactions.Add(new TokenTransaction
                {
                    PlayerId = player.Id,
                    Tipo = TipoTransazione.Override,
                    Motivazione = $"Ricarica per la stagione {nuova.Nome}",
                    Quantita = gettoniNuovi,
                    AdminId = adminPlayerId,
                    AdminNome = adminNome,
                    Timestamp = DateTime.UtcNow
                });
            }

            player.GettoniTotali = gettoniNuovi;
            player.GettoniConsumati = 0;
            // Le quote si ripagano ogni anno: i flag sono la proiezione delle
            // voci di pagamento, e per la stagione nuova non ce ne sono ancora
            player.IscrizionePagata = false;
            player.TesseramentoPagato = false;
        }

        await _context.SaveChangesAsync();
        await tx.CommitAsync();

        _logger.LogInformation(
            "Stagione {Chiusa} chiusa per la squadra {TeamId}, aperta {Nuova}, {N} giocatori azzerati",
            corrente.Nome, teamId, nuova.Nome, players.Count);

        return result;
    }

    /// <summary>
    /// Il nome proposto, oppure lo stesso con un progressivo se la squadra ne ha
    /// gia' una cosi': "2026/27", poi "2026/27 (2)".
    /// </summary>
    private async Task<string> NomeLiberoAsync(int teamId, string proposto)
    {
        var esistenti = await _context.Seasons
            .Where(s => s.TeamId == teamId)
            .Select(s => s.Nome)
            .ToListAsync();

        if (!esistenti.Contains(proposto)) return proposto;

        for (var n = 2; n < 100; n++)
        {
            var candidato = $"{proposto} ({n})";
            if (!esistenti.Contains(candidato)) return candidato;
        }

        return $"{proposto} ({DateTime.UtcNow:yyyyMMddHHmm})";
    }

    /// <summary>
    /// "2026/27" per una stagione che inizia in autunno, altrimenti l'anno solare
    /// corrente: da luglio in poi si considera iniziata la stagione successiva.
    /// </summary>
    internal static string NomeStagione(DateTime quando)
    {
        var anno = quando.Month >= 7 ? quando.Year : quando.Year - 1;
        return $"{anno}/{(anno + 1) % 100:00}";
    }
}
