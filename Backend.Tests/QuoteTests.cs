using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.DTOs.Seasons;
using CalcioAcinque.Backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

/// <summary>Le quote fisse di inizio stagione: idempotenza e confini di stagione.</summary>
public class QuoteTests
{
    [Fact]
    public async Task Genera_una_iscrizione_e_un_tesseramento_per_giocatore()
    {
        using var t = new TestDb();
        var result = await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        Assert.Equal(4, result.Create); // 2 giocatori x 2 quote
        Assert.Equal(0, result.Esentati);
        var voci = await t.Db.PlayerPayments.Where(p => p.TeamId == t.Team.Id).ToListAsync();
        Assert.Equal(4, voci.Count);
        Assert.All(voci, v => Assert.False(v.Pagato));
        Assert.All(voci, v => Assert.NotNull(v.SeasonId));
        Assert.Equal(240m, voci.Sum(v => v.Importo)); // (100 + 20) x 2
    }

    [Fact]
    public async Task Rilanciare_la_generazione_non_crea_duplicati()
    {
        using var t = new TestDb();
        var svc = t.Payments();
        await svc.GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        var seconda = await svc.GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        Assert.Equal(0, seconda.Create);
        Assert.Equal(4, seconda.Invariate);
        Assert.Equal(4, await t.Db.PlayerPayments.CountAsync());
    }

    [Fact]
    public async Task Chi_paga_a_partita_e_esente_dall_iscrizione_ma_non_dal_tesseramento()
    {
        using var t = new TestDb();
        var aPartita = t.AddPlayer("Occasionale", regime: RegimePagamento.APartita);

        var result = await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        Assert.Equal(1, result.Esentati);
        var sue = await t.Db.PlayerPayments.Where(p => p.PlayerId == aPartita.Id).ToListAsync();
        Assert.Single(sue);
        Assert.Equal(TipoPagamento.Tesseramento, sue[0].Tipo);
    }

    [Fact]
    public async Task Dopo_la_chiusura_stagione_le_quote_nuove_si_creano_e_quelle_archiviate_restano_intatte()
    {
        using var t = new TestDb();
        var pagamenti = t.Payments();
        await pagamenti.GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        var vecchia = await t.Seasons().GetCorrenteAsync(t.Team.Id);
        Assert.NotNull(vecchia);

        // Chiusura forzata: le quote della stagione vecchia restano non pagate (100+20 a testa)
        await t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto { IgnoraArretrati = true, NomeNuovaStagione = "Prossima" }, t.Admin.Id);

        // Nel frattempo la squadra alza la quota: NON deve toccare le righe archiviate
        t.Team.QuotaIscrizione = 150m;
        await t.Db.SaveChangesAsync();

        var result = await pagamenti.GenerateFeesAsync(t.Team.Id, new GenerateFeesDto { AggiornaEsistenti = true }, t.Admin.Id);

        Assert.Equal(4, result.Create);
        Assert.Equal(0, result.Aggiornate);
        var archiviate = await t.Db.PlayerPayments.Where(p => p.SeasonId == vecchia!.Id && p.Tipo == TipoPagamento.Iscrizione).ToListAsync();
        Assert.Equal(2, archiviate.Count);
        Assert.All(archiviate, v => Assert.Equal(100m, v.Importo));
        var nuove = await t.Db.PlayerPayments.Where(p => p.SeasonId != vecchia!.Id && p.Tipo == TipoPagamento.Iscrizione).ToListAsync();
        Assert.Equal(2, nuove.Count);
        Assert.All(nuove, v => Assert.Equal(150m, v.Importo));
    }

    [Fact]
    public async Task Senza_costi_configurati_la_generazione_si_ferma_con_un_messaggio()
    {
        using var t = new TestDb();
        t.Team.QuotaIscrizione = 0;
        t.Team.QuotaTesseramento = 0;
        await t.Db.SaveChangesAsync();

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id));
    }
}
