using CalcioAcinque.Backend.DTOs.Attendance;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.DTOs.Seasons;
using CalcioAcinque.Backend.DTOs.Teams;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

/// <summary>
/// Accordi economici del singolo giocatore (esente, importi personali, gettoni
/// solo per lui): toccano quote, addebiti e gettoni, i flussi piu' delicati.
/// </summary>
public class EccezioniGiocatoreTests
{
    [Fact]
    public async Task L_esente_non_riceve_quote_e_non_e_proposto_per_l_addebito_partita()
    {
        using var t = new TestDb();
        var esente = t.AddPlayer("Sponsor", regime: RegimePagamento.Esente);

        var fees = await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);
        Assert.Equal(2, fees.Esentati);
        Assert.False(await t.Db.PlayerPayments.AnyAsync(p => p.PlayerId == esente.Id));

        var match = t.AddMatch();
        var att = t.AddAttendance(match, esente);
        att.Presente = true;
        att.HaGiocato = true;
        await t.Db.SaveChangesAsync();
        var preview = await t.MatchPayments().PreviewAsync(match.Id, t.Team.Id);
        var candidato = preview.Candidati.Single(c => c.PlayerId == esente.Id);
        Assert.False(candidato.Preselezionato);
        Assert.Equal("esente", candidato.Motivo);
    }

    [Fact]
    public async Task Le_quote_personali_vincono_su_quelle_di_squadra_e_zero_vuol_dire_non_la_paga()
    {
        using var t = new TestDb();
        t.Giocatore.QuotaIscrizionePersonale = 50m;
        t.Giocatore.QuotaTesseramentoPersonale = 0m;
        await t.Db.SaveChangesAsync();

        var fees = await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        var sue = await t.Db.PlayerPayments.Where(p => p.PlayerId == t.Giocatore.Id).ToListAsync();
        Assert.Single(sue);
        Assert.Equal(TipoPagamento.Iscrizione, sue[0].Tipo);
        Assert.Equal(50m, sue[0].Importo);
        Assert.Equal(1, fees.Esentati);
        Assert.Equal(170m, fees.TotaleAtteso); // admin 100 + 20, giocatore 50
    }

    [Fact]
    public async Task Una_quota_personale_si_genera_anche_se_la_squadra_non_ne_ha()
    {
        using var t = new TestDb();
        t.Team.QuotaIscrizione = 0m;
        t.Team.QuotaTesseramento = 0m;
        t.Giocatore.QuotaIscrizionePersonale = 30m;
        await t.Db.SaveChangesAsync();

        var fees = await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        Assert.Equal(1, fees.Create);
        Assert.Equal(30m, (await t.Db.PlayerPayments.SingleAsync()).Importo);
    }

    [Fact]
    public async Task Il_costo_partita_personale_vince_sull_importo_uguale_per_tutti()
    {
        using var t = new TestDb();
        t.Giocatore.CostoPartitaPersonale = 3m;
        await t.Db.SaveChangesAsync();
        var match = t.AddMatch();
        t.AddAttendance(match, t.Admin);
        t.AddAttendance(match, t.Giocatore);

        await t.MatchPayments().ConfirmAsync(match.Id, new ConfirmMatchPaymentDto
        {
            PlayerIds = new List<int> { t.Admin.Id, t.Giocatore.Id },
            Importo = 8m,
            InviaNotifica = false,
        }, t.Admin.Id, t.Team.Id);

        var voci = await t.Db.PlayerPayments.Where(p => p.Tipo == TipoPagamento.Partita).ToListAsync();
        Assert.Equal(8m, voci.Single(v => v.PlayerId == t.Admin.Id).Importo);
        Assert.Equal(3m, voci.Single(v => v.PlayerId == t.Giocatore.Id).Importo);
    }

    [Fact]
    public async Task Gettoni_solo_per_lui_in_una_squadra_senza_gettoni()
    {
        using var t = new TestDb();
        t.Team.UseGettoni = false;
        t.Giocatore.GettoniTotali = 0;
        t.Admin.GettoniTotali = 0;
        await t.Db.SaveChangesAsync();

        // Accenderli a stagione in corso gli da' subito la dotazione
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id,
            new UpdatePlayerDto { UsaGettoni = true, GettoniPerStagione = 6 });
        var giocatore = await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id);
        Assert.Equal(6, giocatore.GettoniTotali);

        var match = t.AddMatch();
        t.AddAttendance(match, t.Giocatore);
        t.AddAttendance(match, t.Admin);
        await t.Attendance().UpdateAttendanceAsync(match.Id, t.Giocatore.Id,
            new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);
        await t.Attendance().UpdateAttendanceAsync(match.Id, t.Admin.Id,
            new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);

        Assert.Equal(1, (await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id)).GettoniConsumati);
        Assert.Equal(0, (await t.Db.Players.SingleAsync(p => p.Id == t.Admin.Id)).GettoniConsumati);

        // Nella lista gettoni c'e' solo lui
        var lista = await new TokenService(t.Db).GetTeamTokenSummaryAsync(t.Team.Id);
        Assert.Equal(t.Giocatore.Id, Assert.Single(lista).PlayerId);
    }

    [Fact]
    public async Task Senza_gettoni_per_lui_la_presenza_non_ne_consuma_anche_se_la_squadra_li_usa()
    {
        using var t = new TestDb();
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id, new UpdatePlayerDto { UsaGettoni = false });
        var match = t.AddMatch();
        t.AddAttendance(match, t.Giocatore);

        await t.Attendance().UpdateAttendanceAsync(match.Id, t.Giocatore.Id,
            new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);

        Assert.Equal(0, (await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id)).GettoniConsumati);
    }

    [Fact]
    public async Task La_chiusura_stagione_ricarica_i_gettoni_personali()
    {
        using var t = new TestDb();
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id, new UpdatePlayerDto { GettoniPerStagione = 10 });

        await t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto { IgnoraArretrati = true }, t.Admin.Id);

        Assert.Equal(10, (await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id)).GettoniTotali);
        Assert.Equal(4, (await t.Db.Players.SingleAsync(p => p.Id == t.Admin.Id)).GettoniTotali);
    }

    [Fact]
    public async Task Reimposta_torna_ai_valori_della_squadra()
    {
        using var t = new TestDb();
        await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id,
            new UpdatePlayerDto { CostoPartitaPersonale = 5m, UsaGettoni = false });
        var dto = await t.Players().UpdateAsync(t.Team.Id, t.Giocatore.Id,
            new UpdatePlayerDto { ReimpostaCostoPartita = true, ReimpostaUsaGettoni = true });

        Assert.Null(dto.CostoPartitaPersonale);
        Assert.Equal(t.Team.CostoPartita, dto.CostoPartitaEffettivo);
        Assert.Null(dto.UsaGettoni);
        Assert.True(dto.UsaGettoniEffettivo);
    }

    [Fact]
    public async Task Esente_non_puo_essere_il_default_della_squadra()
    {
        using var t = new TestDb();
        await new TeamService(t.Db).UpdateAsync(t.Team.Id, new UpdateTeamDto { RegimePagamentoDefault = "Esente" });
        Assert.Equal(RegimePagamento.Stagionale, (await t.Db.Teams.SingleAsync()).RegimePagamentoDefault);
    }
}
