using CalcioAcinque.Backend.DTOs.Attendance;
using CalcioAcinque.Backend.DTOs.Convocations;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

/// <summary>
/// Addebito partita quando il giocatore e' segnato in campo, entrate ignorate dall'admin e voci
/// riallineate quando cambia l'accordo del giocatore.
/// </summary>
public class AddebitiEIgnoratiTests
{
    [Fact]
    public async Task Chi_paga_a_partita_riceve_l_addebito_solo_quando_e_segnato_in_campo()
    {
        using var t = new TestDb();
        t.Team.CostoPartita = 8m;
        var occasionale = t.AddPlayer("Occasionale", regime: RegimePagamento.APartita);
        occasionale.CostoPartitaPersonale = 6m;
        await t.Db.SaveChangesAsync();
        var match = t.AddMatch(StatoPartita.Programmata);

        // La convocazione non addebita nulla
        await t.Convocations().SendConvocationsAsync(match.Id,
            new SendConvocationsDto { PlayerIds = new() { occasionale.Id, t.Giocatore.Id } }, t.Team.Id);
        Assert.False(await t.Db.PlayerPayments.AnyAsync());

        // Presente non basta: serve "in campo"
        foreach (var id in new[] { occasionale.Id, t.Giocatore.Id })
            await t.Attendance().UpdateAttendanceAsync(match.Id, id,
                new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);
        Assert.False(await t.Db.PlayerPayments.AnyAsync());

        foreach (var id in new[] { occasionale.Id, t.Giocatore.Id })
            await t.Attendance().UpdateAttendanceAsync(match.Id, id,
                new UpdateAttendanceDto { HaGiocato = true }, t.Admin.Id, t.Team.Id);

        // Solo chi paga a partita, col suo costo personale e il riferimento alla partita
        var voce = await t.Db.PlayerPayments.SingleAsync();
        Assert.Equal(occasionale.Id, voce.PlayerId);
        Assert.Equal(match.Id, voce.MatchId);
        Assert.Equal(TipoPagamento.Partita, voce.Tipo);
        Assert.Equal(6m, voce.Importo);

        // Tolto dal campo: via l'addebito
        await t.Attendance().UpdateAttendanceAsync(match.Id, occasionale.Id,
            new UpdateAttendanceDto { HaGiocato = false }, t.Admin.Id, t.Team.Id);
        Assert.False(await t.Db.PlayerPayments.AnyAsync());
    }

    [Fact]
    public async Task Un_addebito_gia_dichiarato_o_messo_a_mano_non_sparisce_togliendolo_dal_campo()
    {
        using var t = new TestDb();
        t.Team.CostoPartita = 8m;
        var occasionale = t.AddPlayer("Occasionale", regime: RegimePagamento.APartita);
        var match = t.AddMatch();
        t.AddAttendance(match, occasionale);
        await t.Attendance().UpdateAttendanceAsync(match.Id, occasionale.Id,
            new UpdateAttendanceDto { Presente = true, HaGiocato = true }, t.Admin.Id, t.Team.Id);
        var voce = await t.Db.PlayerPayments.SingleAsync();
        await t.Payments().DeclareAsync(voce.Id, occasionale.Id, t.Team.Id);

        await t.Attendance().UpdateAttendanceAsync(match.Id, occasionale.Id,
            new UpdateAttendanceDto { HaGiocato = false }, t.Admin.Id, t.Team.Id);

        Assert.Equal(1, await t.Db.PlayerPayments.CountAsync());
    }

    [Fact]
    public async Task Un_entrata_ignorata_esce_da_arretrati_attese_e_chiusura_stagione()
    {
        using var t = new TestDb();
        await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        var voci = await t.Db.PlayerPayments.Where(p => p.PlayerId == t.Giocatore.Id).ToListAsync();
        foreach (var v in voci) await t.Payments().IgnoraAsync(v.Id, true, t.Team.Id);

        var cassa = await t.Expenses().GetCassaAsync(t.Team.Id, null);
        Assert.Equal(120m, cassa.EntrateAttese); // solo quelle dell'admin
        Assert.DoesNotContain(cassa.Arretrati, a => a.PlayerId == t.Giocatore.Id);

        // Ripristinata torna tra le attese
        await t.Payments().IgnoraAsync(voci[0].Id, false, t.Team.Id);
        cassa = await t.Expenses().GetCassaAsync(t.Team.Id, null);
        Assert.Equal(120m + voci[0].Importo, cassa.EntrateAttese);
    }

    [Fact]
    public async Task Una_voce_incassata_non_si_ignora_e_incassarla_toglie_l_ignorato()
    {
        using var t = new TestDb();
        await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        var voce = await t.Db.PlayerPayments.FirstAsync(p => p.PlayerId == t.Giocatore.Id);

        await t.Payments().IgnoraAsync(voce.Id, true, t.Team.Id);
        await t.Payments().UpdateAsync(voce.Id, new UpdatePaymentDto { Pagato = true }, t.Team.Id);
        var dopo = await t.Db.PlayerPayments.AsNoTracking().SingleAsync(p => p.Id == voce.Id);
        Assert.True(dopo.Pagato);
        Assert.False(dopo.Ignorato);

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Payments().IgnoraAsync(voce.Id, true, t.Team.Id));
    }

    [Fact]
    public async Task Cambiare_accordo_riallinea_le_quote_non_pagate_e_si_puo_tornare_indietro()
    {
        using var t = new TestDb();
        await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        // Esente: le sue quote aperte diventano ignorate
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id, new UpdatePlayerDto { RegimePagamento = "Esente" });
        var sue = await t.Db.PlayerPayments.AsNoTracking().Where(p => p.PlayerId == t.Giocatore.Id).ToListAsync();
        Assert.All(sue, v => Assert.True(v.Ignorato));

        // Di nuovo come la squadra, con un'iscrizione personale: tornano dovute
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id,
            new UpdatePlayerDto { RegimePagamento = "", QuotaIscrizionePersonale = 40m });
        sue = await t.Db.PlayerPayments.AsNoTracking().Where(p => p.PlayerId == t.Giocatore.Id).ToListAsync();
        Assert.All(sue, v => Assert.False(v.Ignorato));
        Assert.Equal(40m, sue.Single(v => v.Tipo == TipoPagamento.Iscrizione).Importo);
        Assert.Equal(20m, sue.Single(v => v.Tipo == TipoPagamento.Tesseramento).Importo);
    }

    [Fact]
    public async Task Il_riallineamento_non_tocca_le_voci_gia_pagate_ne_quelle_ignorate_dall_admin()
    {
        using var t = new TestDb();
        await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        var iscr = await t.Db.PlayerPayments.FirstAsync(p => p.PlayerId == t.Giocatore.Id && p.Tipo == TipoPagamento.Iscrizione);
        var tess = await t.Db.PlayerPayments.FirstAsync(p => p.PlayerId == t.Giocatore.Id && p.Tipo == TipoPagamento.Tesseramento);
        await t.Payments().UpdateAsync(iscr.Id, new UpdatePaymentDto { Pagato = true }, t.Team.Id);
        await t.Payments().IgnoraAsync(tess.Id, true, t.Team.Id);

        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id,
            new UpdatePlayerDto { QuotaIscrizionePersonale = 10m, QuotaTesseramentoPersonale = 5m });

        var dopoIscr = await t.Db.PlayerPayments.AsNoTracking().SingleAsync(p => p.Id == iscr.Id);
        var dopoTess = await t.Db.PlayerPayments.AsNoTracking().SingleAsync(p => p.Id == tess.Id);
        Assert.Equal(100m, dopoIscr.Importo);
        Assert.True(dopoTess.Ignorato);
        Assert.Equal(20m, dopoTess.Importo);
    }
}
