using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

/// <summary>
/// Addebiti partita per chi paga a partita, creati gia' alla convocazione:
/// la voce "da pagare" legata alla partita c'e' da subito, invece di aspettare
/// l'incasso a fine partita. Chi esce dai convocati (revoca, forfait) la perde,
/// finche' non l'ha pagata o dichiarata.
/// </summary>
internal static class AddebitiPartita
{
    /// <summary>Firma delle voci create alla convocazione (al posto del nome dell'admin).</summary>
    public const string AutoreConvocazione = "Convocazione";

    public static async Task CreaAsync(ApplicationDbContext context, Match match, Team team, IEnumerable<Player> players)
    {
        var lista = players.Where(p => RegimiPagamento.Effettivo(p.RegimePagamento, team.RegimePagamentoDefault)
                                       == RegimePagamento.APartita).ToList();
        if (lista.Count == 0) return;

        var ids = lista.Select(p => p.Id).ToList();
        // Uno per giocatore e partita (indice unico): se c'e' gia' non si tocca
        var esistenti = await context.PlayerPayments
            .Where(p => p.MatchId == match.Id && p.PlayerId != null && ids.Contains(p.PlayerId.Value))
            .Select(p => p.PlayerId!.Value)
            .ToListAsync();

        foreach (var player in lista.Where(p => !esistenti.Contains(p.Id)))
        {
            var importo = player.CostoPartitaPersonale ?? team.CostoPartita;
            if (importo <= 0) continue;
            context.PlayerPayments.Add(new PlayerPayment
            {
                TeamId = team.Id,
                SeasonId = match.SeasonId,
                PlayerId = player.Id,
                NomeGiocatore = player.Nome,
                MatchId = match.Id,
                Tipo = TipoPagamento.Partita,
                Descrizione = MatchPaymentService.DescriviPartita(match),
                Importo = importo,
                DataPagamento = match.Data.Date,
                Pagato = false,
                AdminNome = AutoreConvocazione,
                CreatedAt = DateTime.UtcNow
            });
        }
    }

    /// <summary>Toglie l'addebito partita se non e' ancora stato pagato ne' dichiarato.</summary>
    public static async Task TogliAsync(ApplicationDbContext context, int matchId, int playerId)
    {
        var voce = await context.PlayerPayments.FirstOrDefaultAsync(p =>
            p.MatchId == matchId && p.PlayerId == playerId && p.Tipo == TipoPagamento.Partita);
        if (voce != null && !voce.Pagato && voce.DichiaratoPagatoAt == null)
            context.PlayerPayments.Remove(voce);
    }
}
