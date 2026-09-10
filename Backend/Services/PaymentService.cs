using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IPaymentService
{
    /// <summary>
    /// Voci della squadra. <paramref name="soloDelPlayerId"/> va passato per chi non
    /// gestisce la cassa: il filtro sta qui e non nel client, altrimenti chiunque
    /// vedrebbe i conti di tutti.
    /// </summary>
    Task<List<PlayerPaymentDto>> GetByTeamAsync(
        int teamId, int? soloDelPlayerId = null, int? seasonId = null);

    Task<List<PlayerPaymentDto>> GetByPlayerAsync(int playerId, int teamId);
    Task<PlayerPaymentDto> CreateAsync(int playerId, CreatePaymentDto dto, int adminPlayerId, int teamId);
    Task<PlayerPaymentDto> UpdateAsync(int paymentId, UpdatePaymentDto dto, int teamId);
    Task<GenerateFeesResultDto> GenerateFeesAsync(int teamId, GenerateFeesDto dto, int adminPlayerId);

    /// <summary>Il giocatore dichiara di aver pagato: la voce va "in verifica", la conferma resta all'admin.</summary>
    Task<PlayerPaymentDto> DeclareAsync(int paymentId, int playerId, int teamId);

    /// <summary>Sollecito manuale a chi ha voci non saldate.</summary>
    Task<RemindResultDto> RemindAsync(int teamId, RemindDto dto);
}

public class PaymentService : IPaymentService
{
    private const string DescrizioneIscrizione = "Quota iscrizione";
    private const string DescrizioneTesseramento = "Quota tesseramento";

    private readonly ApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ISeasonService _seasons;

    public PaymentService(
        ApplicationDbContext context,
        INotificationService notifications,
        ISeasonService seasons)
    {
        _context = context;
        _notifications = notifications;
        _seasons = seasons;
    }

    public async Task<List<PlayerPaymentDto>> GetByTeamAsync(
        int teamId, int? soloDelPlayerId = null, int? seasonId = null)
    {
        // Si filtra su PlayerPayment.TeamId e non su Player.TeamId: le voci di un
        // giocatore cancellato hanno PlayerId null e non devono sparire dai conti.
        var query = _context.PlayerPayments.Where(p => p.TeamId == teamId);

        if (soloDelPlayerId.HasValue)
            query = query.Where(p => p.PlayerId == soloDelPlayerId.Value);

        // Come per le partite: senza stagione richiesta si vede quella aperta
        var stagione = seasonId ?? (await _seasons.GetCorrenteAsync(teamId))?.Id;
        if (stagione.HasValue)
            query = query.Where(p => p.SeasonId == stagione.Value || p.SeasonId == null);

        var payments = await query.OrderByDescending(p => p.DataPagamento).ToListAsync();
        return payments.Select(MapToDto).ToList();
    }

    public async Task<List<PlayerPaymentDto>> GetByPlayerAsync(int playerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        var payments = await _context.PlayerPayments
            .Where(p => p.PlayerId == playerId).OrderByDescending(p => p.DataPagamento).ToListAsync();
        return payments.Select(MapToDto).ToList();
    }

    public async Task<PlayerPaymentDto> CreateAsync(int playerId, CreatePaymentDto dto, int adminPlayerId, int teamId)
    {
        var player = await _context.Players.FindAsync(playerId);
        if (player == null) throw new NotFoundException("Giocatore", playerId);
        if (player.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        if (dto.Importo < 0)
            throw new BadRequestException("L'importo non puo' essere negativo");

        var stagione = await _seasons.GetOrCreateCorrenteAsync(teamId);
        var payment = new PlayerPayment
        {
            TeamId = teamId,
            SeasonId = stagione.Id,
            PlayerId = playerId,
            NomeGiocatore = player.Nome,
            Descrizione = dto.Descrizione,
            Importo = dto.Importo,
            Tipo = ParseTipo(dto.Tipo),
            DataPagamento = dto.DataPagamento,
            Pagato = dto.Pagato,
            Note = dto.Note,
            AdminId = adminPlayerId,
            AdminNome = await NomeAdminAsync(adminPlayerId),
            CreatedAt = DateTime.UtcNow
        };
        _context.PlayerPayments.Add(payment);
        SincronizzaFlagQuota(payment, player);
        await _context.SaveChangesAsync();
        return MapToDto(payment);
    }

    public async Task<PlayerPaymentDto> UpdateAsync(int paymentId, UpdatePaymentDto dto, int teamId)
    {
        var payment = await _context.PlayerPayments
            .Include(p => p.Player)
            .FirstOrDefaultAsync(p => p.Id == paymentId);
        if (payment == null) throw new NotFoundException("Pagamento", paymentId);
        if (payment.TeamId != teamId) throw new UnauthorizedException("Non sei autorizzato ad accedere a questa risorsa");

        if (dto.Descrizione != null) payment.Descrizione = dto.Descrizione;
        if (dto.DataPagamento.HasValue) payment.DataPagamento = dto.DataPagamento.Value;
        if (dto.Note != null) payment.Note = dto.Note;

        if (dto.Importo.HasValue)
        {
            if (dto.Importo.Value < 0)
                throw new BadRequestException("L'importo non puo' essere negativo");
            payment.Importo = dto.Importo.Value;
        }

        if (dto.Pagato.HasValue)
        {
            payment.Pagato = dto.Pagato.Value;
            // Confermato o rifiutato dall'admin: la dichiarazione del giocatore
            // ha esaurito il suo scopo e non deve restare appesa come "in verifica"
            payment.DichiaratoPagatoAt = null;
            SincronizzaFlagQuota(payment, payment.Player);
        }

        await _context.SaveChangesAsync();
        return MapToDto(payment);
    }

    /// <summary>
    /// Trasforma i costi configurati sulla squadra in voci di pagamento, una per giocatore.
    /// E' idempotente: le quote sono riconosciute dalla descrizione canonica, quindi
    /// rilanciarla non crea duplicati. Chi paga a partita puo' essere esentato dalle
    /// quote fisse, secondo <see cref="Team.ApplicaIscrizioneA"/> e <see cref="Team.ApplicaTesseramentoA"/>.
    /// </summary>
    public async Task<GenerateFeesResultDto> GenerateFeesAsync(int teamId, GenerateFeesDto dto, int adminPlayerId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) throw new NotFoundException("Team", teamId);

        var quote = new List<QuotaFissa>();
        if (dto.Iscrizione && team.QuotaIscrizione > 0)
            quote.Add(new QuotaFissa(DescrizioneIscrizione, team.QuotaIscrizione, TipoPagamento.Iscrizione,
                team.ApplicaIscrizioneA, p => p.IscrizionePagata));
        if (dto.Tesseramento && team.QuotaTesseramento > 0)
            quote.Add(new QuotaFissa(DescrizioneTesseramento, team.QuotaTesseramento, TipoPagamento.Tesseramento,
                team.ApplicaTesseramentoA, p => p.TesseramentoPagato));

        if (quote.Count == 0)
            throw new BusinessException(
                "Nessuna quota da generare: configura gli importi nelle impostazioni della squadra");

        var players = await _context.Players.Where(p => p.TeamId == teamId).OrderBy(p => p.Nome).ToListAsync();
        var playerIds = players.Select(p => p.Id).ToList();
        var descrizioni = quote.Select(q => q.Descrizione).ToList();

        var esistenti = await _context.PlayerPayments
            .Where(p => p.PlayerId != null && playerIds.Contains(p.PlayerId.Value)
                        && descrizioni.Contains(p.Descrizione))
            .ToListAsync();

        var data = (dto.Data ?? DateTime.UtcNow).Date;
        var adminNome = await NomeAdminAsync(adminPlayerId);
        var stagione = await _seasons.GetOrCreateCorrenteAsync(teamId);
        var result = new GenerateFeesResultDto();

        foreach (var player in players)
        {
            // Il filtro per regime va qui, sul singolo giocatore: deciderlo a monte
            // sulla lista `quote` significherebbe applicarlo a tutta la squadra.
            var regime = RegimiPagamento.Effettivo(player.RegimePagamento, team.RegimePagamentoDefault);

            foreach (var quota in quote)
            {
                if (!RegimiPagamento.QuotaDovuta(quota.Destinatari, regime))
                {
                    result.Esentati++;
                    continue;
                }

                var esistente = esistenti.FirstOrDefault(
                    e => e.PlayerId == player.Id && e.Descrizione == quota.Descrizione);

                if (esistente == null)
                {
                    _context.PlayerPayments.Add(new PlayerPayment
                    {
                        TeamId = teamId,
                        SeasonId = stagione.Id,
                        PlayerId = player.Id,
                        NomeGiocatore = player.Nome,
                        Descrizione = quota.Descrizione,
                        Importo = quota.Importo,
                        Tipo = quota.Tipo,
                        DataPagamento = data,
                        // I flag storici sul giocatore inizializzano il "gia' pagato";
                        // da qui in avanti e' la voce a comandare (SincronizzaFlagQuota)
                        Pagato = quota.GiaPagata(player),
                        AdminId = adminPlayerId,
                        AdminNome = adminNome,
                        CreatedAt = DateTime.UtcNow
                    });
                    result.Create++;
                }
                else if (dto.AggiornaEsistenti && !esistente.Pagato && esistente.Importo != quota.Importo)
                {
                    esistente.Importo = quota.Importo;
                    esistente.Tipo = quota.Tipo;
                    result.Aggiornate++;
                }
                else
                {
                    result.Invariate++;
                }

                result.TotaleAtteso += quota.Importo;
            }
        }

        await _context.SaveChangesAsync();
        result.Pagamenti = await GetByTeamAsync(teamId);
        return result;
    }

    public async Task<PlayerPaymentDto> DeclareAsync(int paymentId, int playerId, int teamId)
    {
        var payment = await _context.PlayerPayments
            .FirstOrDefaultAsync(p => p.Id == paymentId);
        if (payment == null) throw new NotFoundException("Pagamento", paymentId);

        // Si dichiara solo per se stessi, e la squadra deve tornare
        if (payment.PlayerId != playerId || payment.TeamId != teamId)
            throw new UnauthorizedException("Puoi segnalare solo i tuoi pagamenti");

        if (payment.Pagato)
            throw new BusinessException("Questa voce risulta gia' saldata");

        payment.DichiaratoPagatoAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return MapToDto(payment);
    }

    public async Task<RemindResultDto> RemindAsync(int teamId, RemindDto dto)
    {
        var players = await _context.Players
            .Where(p => p.TeamId == teamId)
            .ToListAsync();

        // Nessun elenco = sollecita tutti quelli che hanno qualcosa da pagare
        if (dto.PlayerIds.Count > 0)
            players = players.Where(p => dto.PlayerIds.Contains(p.Id)).ToList();

        if (players.Count == 0)
            throw new BusinessException("Nessun giocatore da sollecitare");

        var team = await _context.Teams.FindAsync(teamId);
        var playerIds = players.Select(p => p.Id).ToList();

        var stagione = await _seasons.GetCorrenteAsync(teamId);
        var arretrati = await _context.PlayerPayments
            .Where(p => p.PlayerId != null && playerIds.Contains(p.PlayerId.Value) && !p.Pagato
                        && (stagione == null || p.SeasonId == stagione.Id || p.SeasonId == null))
            .GroupBy(p => p.PlayerId!.Value)
            .Select(g => new { PlayerId = g.Key, Totale = g.Sum(x => x.Importo), Voci = g.Count() })
            .ToListAsync();

        var result = new RemindResultDto();

        foreach (var arretrato in arretrati)
        {
            var player = players.First(p => p.Id == arretrato.PlayerId);
            var voci = arretrato.Voci == 1 ? "1 voce" : $"{arretrato.Voci} voci";

            var accodate = await _notifications.QueueAsync(
                NotificationKind.PagamentoDovuto,
                new[] { player.UserId },
                titolo: team != null ? $"{team.Nome}: pagamento da saldare" : "Pagamento da saldare",
                corpo: $"Hai {voci} da pagare, totale {Euro(arretrato.Totale)}.",
                url: "/payments",
                tag: $"sollecito-{player.Id}",
                teamId: teamId);

            result.Sollecitati += accodate > 0 ? 1 : 0;
            result.SenzaDispositivo += accodate > 0 ? 0 : 1;
            result.TotaleArretrato += arretrato.Totale;
        }

        result.SenzaArretrati = players.Count - arretrati.Count;
        return result;
    }

    internal static string Euro(decimal value) =>
        value == decimal.Truncate(value) ? $"{value:0} EUR" : $"{value:0.00} EUR";

    /// <summary>
    /// Tiene allineati i flag storici sul giocatore. La voce di pagamento e' la
    /// fonte di verita': i flag restano perche' li usano rosa e anagrafica, ma
    /// sono una proiezione e non si modificano piu' a mano.
    /// </summary>
    private static void SincronizzaFlagQuota(PlayerPayment payment, Player? player)
    {
        if (player == null) return;

        switch (payment.Tipo)
        {
            case TipoPagamento.Iscrizione:
                player.IscrizionePagata = payment.Pagato;
                break;
            case TipoPagamento.Tesseramento:
                player.TesseramentoPagato = payment.Pagato;
                break;
        }
    }

    private async Task<string?> NomeAdminAsync(int adminPlayerId) =>
        await _context.Players
            .Where(p => p.Id == adminPlayerId)
            .Select(p => p.Nome)
            .FirstOrDefaultAsync();

    private static TipoPagamento ParseTipo(string? value) =>
        Enum.TryParse<TipoPagamento>(value, true, out var tipo) ? tipo : TipoPagamento.Altro;

    private static PlayerPaymentDto MapToDto(PlayerPayment p) => new()
    {
        Id = p.Id, PlayerId = p.PlayerId ?? 0,
        // Nomi congelati nella riga: restano leggibili anche se le persone non ci sono piu'
        NomeGiocatore = p.NomeGiocatore, Descrizione = p.Descrizione,
        Importo = p.Importo, DataPagamento = p.DataPagamento, Pagato = p.Pagato, Note = p.Note,
        AdminNome = p.AdminNome ?? string.Empty, CreatedAt = p.CreatedAt,
        Tipo = p.Tipo.ToString(), MatchId = p.MatchId,
        DichiaratoPagatoAt = p.DichiaratoPagatoAt,
        GiocatoreRimosso = p.PlayerId == null
    };

    /// <summary>Una quota fissa da generare, coi suoi destinatari.</summary>
    private sealed record QuotaFissa(
        string Descrizione,
        decimal Importo,
        TipoPagamento Tipo,
        DestinatariQuota Destinatari,
        Func<Player, bool> GiaPagata);
}
