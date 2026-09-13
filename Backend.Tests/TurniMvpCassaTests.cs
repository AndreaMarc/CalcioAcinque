using CalcioAcinque.Backend.DTOs.Cassa;
using CalcioAcinque.Backend.DTOs.Chores;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

public class TurniTests
{
    [Fact]
    public async Task La_rotazione_sceglie_chi_non_lo_fa_da_piu_tempo_e_un_turno_a_testa()
    {
        using var t = new TestDb();
        var a = t.Admin;
        var b = t.Giocatore;
        var c = t.AddPlayer("Carlo");
        var chores = t.Chores();
        var casacche = await chores.CreateAsync(t.Team.Id, new UpsertChoreDto { Nome = "Casacche" });
        var palloni = await chores.CreateAsync(t.Team.Id, new UpsertChoreDto { Nome = "Palloni" });

        // Partita 1: nessuno storico, decide il nome (Admin, Carlo, Gigi)
        var m1 = t.AddMatch(StatoPartita.ConvocazioniInviate);
        t.Db.Matches.Single(m => m.Id == m1.Id).Data = DateTime.UtcNow.Date.AddDays(-7);
        t.Db.SaveChanges();
        foreach (var p in new[] { a, b, c }) t.AddConvocation(m1, p, StatoRisposta.Confermato);
        var turni1 = await chores.AssignAsync(m1.Id, t.Team.Id);

        Assert.Equal(2, turni1.Count);
        Assert.NotEqual(turni1[0].PlayerId, turni1[1].PlayerId); // un turno a testa
        Assert.Equal(a.Id, turni1.Single(x => x.ChoreId == casacche.Id).PlayerId);
        Assert.Equal(c.Id, turni1.Single(x => x.ChoreId == palloni.Id).PlayerId);

        // Partita 2: Gigi non ha mai fatto niente, va per primo; poi uno degli altri due
        var m2 = t.AddMatch(StatoPartita.ConvocazioniInviate);
        foreach (var p in new[] { a, b, c }) t.AddConvocation(m2, p, StatoRisposta.Confermato);
        var turni2 = await chores.AssignAsync(m2.Id, t.Team.Id);

        Assert.Equal(b.Id, turni2.Single(x => x.ChoreId == casacche.Id).PlayerId);
        Assert.Contains(turni2.Single(x => x.ChoreId == palloni.Id).PlayerId, new int?[] { a.Id, c.Id });
    }

    [Fact]
    public async Task Chi_ha_dato_forfait_non_riceve_turni_e_a_mano_si_corregge()
    {
        using var t = new TestDb();
        var chores = t.Chores();
        var casacche = await chores.CreateAsync(t.Team.Id, new UpsertChoreDto { Nome = "Casacche" });
        var match = t.AddMatch(StatoPartita.ConvocazioniInviate);
        t.AddConvocation(match, t.Admin, StatoRisposta.NonDisponibile);
        t.AddConvocation(match, t.Giocatore, StatoRisposta.InAttesa);

        var turni = await chores.AssignAsync(match.Id, t.Team.Id);
        Assert.Equal(t.Giocatore.Id, turni.Single().PlayerId);

        // Il mister libera il turno e poi lo da' a mano
        var liberi = await chores.SetAsync(match.Id, casacche.Id, null, t.Team.Id);
        Assert.Null(liberi.Single().PlayerId);
        var aMano = await chores.SetAsync(match.Id, casacche.Id, t.Admin.Id, t.Team.Id);
        Assert.Equal(t.Admin.Id, aMano.Single().PlayerId);
    }

    [Fact]
    public async Task Senza_turni_o_senza_convocati_si_rifiuta()
    {
        using var t = new TestDb();
        var match = t.AddMatch(StatoPartita.ConvocazioniInviate);
        await Assert.ThrowsAsync<Exceptions.BusinessException>(() => t.Chores().AssignAsync(match.Id, t.Team.Id));

        await t.Chores().CreateAsync(t.Team.Id, new UpsertChoreDto { Nome = "Casacche" });
        await Assert.ThrowsAsync<Exceptions.BusinessException>(() => t.Chores().AssignAsync(match.Id, t.Team.Id));
    }
}

public class MvpTests
{
    [Fact]
    public async Task Si_vota_solo_a_partita_conclusa_solo_presenti_e_mai_se_stessi()
    {
        using var t = new TestDb();
        var votes = t.Votes();
        var altro = t.AddPlayer("Carlo");
        var match = t.AddMatch(StatoPartita.InCorso);
        var att = t.AddAttendance(match, t.Giocatore);
        att.Presente = true;
        t.Db.SaveChanges();

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, t.Giocatore.Id));

        t.Db.Matches.Single(m => m.Id == match.Id).Stato = StatoPartita.Conclusa;
        t.Db.SaveChanges();

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, t.Admin.Id));
        // Carlo non era presente
        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, altro.Id));

        var dto = await votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, t.Giocatore.Id);
        Assert.True(dto.Aperto);
        Assert.Equal(t.Giocatore.Id, dto.MioVotoPlayerId);
        Assert.Equal(1, dto.TotaleVoti);
        Assert.Equal(t.Giocatore.Id, dto.Classifica.Single().PlayerId);
    }

    [Fact]
    public async Task Un_voto_per_votante_cambiarlo_lo_sostituisce_e_si_puo_togliere()
    {
        using var t = new TestDb();
        var votes = t.Votes();
        var carlo = t.AddPlayer("Carlo");
        var match = t.AddMatch(StatoPartita.Conclusa);
        foreach (var p in new[] { t.Giocatore, carlo })
        {
            var att = t.AddAttendance(match, p);
            att.Presente = true;
        }
        t.Db.SaveChanges();

        await votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, t.Giocatore.Id);
        var cambiato = await votes.VoteAsync(match.Id, t.Team.Id, t.Admin.Id, carlo.Id);
        Assert.Equal(1, cambiato.TotaleVoti);
        Assert.Equal(carlo.Id, cambiato.Classifica.Single().PlayerId);
        Assert.Equal(1, await t.Db.MatchVotes.CountAsync());

        var tolto = await votes.RemoveVoteAsync(match.Id, t.Team.Id, t.Admin.Id);
        Assert.Null(tolto.MioVotoPlayerId);
        Assert.Equal(0, tolto.TotaleVoti);
    }
}

public class CassaTests
{
    [Fact]
    public async Task Il_costo_campo_diviso_arrotonda_a_50_cent_e_registra_l_uscita()
    {
        using var t = new TestDb();
        var team = t.Db.Teams.Single(x => x.Id == t.Team.Id);
        team.CostoPartita = 5m;
        team.RegimePagamentoDefault = RegimePagamento.APartita;
        t.Db.SaveChanges();
        var carlo = t.AddPlayer("Carlo");
        var match = t.AddMatch(StatoPartita.Conclusa);
        foreach (var p in new[] { t.Admin, t.Giocatore, carlo })
        {
            var att = t.AddAttendance(match, p);
            att.Presente = true;
            att.HaGiocato = true;
        }
        t.Db.SaveChanges();

        // 70 / 3 = 23.33 -> 23.50 a testa
        var result = await t.MatchPayments().ConfirmAsync(match.Id, new ConfirmMatchPaymentDto
        {
            PlayerIds = new List<int> { t.Admin.Id, t.Giocatore.Id, carlo.Id },
            SpesaCampo = 70m,
            DividiSpesaCampo = true,
            InviaNotifica = false,
        }, t.Admin.Id, t.Team.Id);

        Assert.Equal(3, result.Addebitati);
        Assert.Equal(70.5m, result.TotaleAddebitato);
        var uscita = await t.Db.TeamExpenses.SingleAsync();
        Assert.Equal(match.Id, uscita.MatchId);
        Assert.Equal(CategoriaSpesa.Campo, uscita.Categoria);
        Assert.Equal(70m, uscita.Importo);

        // Ripetere l'incasso con una spesa diversa aggiorna l'uscita invece di duplicarla
        await t.MatchPayments().ConfirmAsync(match.Id, new ConfirmMatchPaymentDto
        {
            PlayerIds = new List<int> { t.Admin.Id },
            SpesaCampo = 80m,
            InviaNotifica = false,
        }, t.Admin.Id, t.Team.Id);
        Assert.Equal(1, await t.Db.TeamExpenses.CountAsync());
        Assert.Equal(80m, (await t.Db.TeamExpenses.SingleAsync()).Importo);

        var cassa = await t.Expenses().GetCassaAsync(t.Team.Id, null);
        Assert.Equal(80m, cassa.Uscite);
        Assert.Equal(70.5m, cassa.EntrateAttese);
        Assert.Equal(0m, cassa.EntrateIncassate);
        Assert.Equal(-80m, cassa.Saldo);
        Assert.Equal(3, cassa.Arretrati.Count);
        Assert.Empty(cassa.PartiteNonIncassate);
    }

    [Fact]
    public async Task Una_partita_conclusa_senza_addebiti_compare_tra_quelle_da_incassare()
    {
        using var t = new TestDb();
        var team = t.Db.Teams.Single(x => x.Id == t.Team.Id);
        team.RegimePagamentoDefault = RegimePagamento.APartita;
        t.Db.SaveChanges();
        var match = t.AddMatch(StatoPartita.Conclusa);
        var att = t.AddAttendance(match, t.Giocatore);
        att.Presente = true;
        t.Db.SaveChanges();

        var cassa = await t.Expenses().GetCassaAsync(t.Team.Id, null);
        var da = Assert.Single(cassa.PartiteNonIncassate);
        Assert.Equal(match.Id, da.MatchId);
        Assert.Equal(1, da.PresentiAPartita);
    }

    [Fact]
    public async Task Le_uscite_si_creano_modificano_e_cancellano_solo_nella_propria_squadra()
    {
        using var t = new TestDb();
        var svc = t.Expenses();
        var e = await svc.CreateAsync(t.Team.Id, new UpsertExpenseDto { Categoria = "Arbitro", Descrizione = "Arbitro G1", Importo = 30m }, t.Admin.Id);
        Assert.Equal("Arbitro", e.Categoria);

        var mod = await svc.UpdateAsync(e.Id, t.Team.Id, new UpsertExpenseDto { Categoria = "Altro", Descrizione = "Arbitro G1", Importo = 35m });
        Assert.Equal(35m, mod.Importo);

        await Assert.ThrowsAnyAsync<Exception>(() => svc.DeleteAsync(e.Id, t.Team.Id + 99));
        await svc.DeleteAsync(e.Id, t.Team.Id);
        Assert.Empty(await svc.GetByTeamAsync(t.Team.Id, null));
    }
}
