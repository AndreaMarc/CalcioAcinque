using CalcioAcinque.Backend.DTOs.Attendance;
using CalcioAcinque.Backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

/// <summary>
/// Il gettone e' l'unico contatore persistente che cambia da solo con le presenze:
/// se sbaglia, i giocatori pagano partite che non hanno fatto o giocano gratis.
/// </summary>
public class GettoniTests
{
    [Fact]
    public async Task Presenza_consuma_un_gettone_e_lascia_traccia()
    {
        using var t = new TestDb();
        var match = t.AddMatch();
        t.AddAttendance(match, t.Giocatore);

        await t.Attendance().UpdateAttendanceAsync(match.Id, t.Giocatore.Id,
            new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);

        var player = await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id);
        Assert.Equal(1, player.GettoniConsumati);
        Assert.Equal(3, player.GettoniRimanenti);
        var mov = await t.Db.TokenTransactions.SingleAsync(x => x.PlayerId == player.Id);
        Assert.Equal(-1, mov.Quantita);
        Assert.Equal(TipoTransazione.ConsumoAutomatico, mov.Tipo);
        Assert.Equal(match.Id, mov.MatchId);
    }

    [Fact]
    public async Task Presenza_a_gettoni_esauriti_non_va_sotto_zero_ma_resta_registrata()
    {
        using var t = new TestDb();
        var senza = t.AddPlayer("Vuoto", gettoni: 0);
        var match = t.AddMatch();
        t.AddAttendance(match, senza);

        await t.Attendance().UpdateAttendanceAsync(match.Id, senza.Id,
            new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);

        var player = await t.Db.Players.SingleAsync(p => p.Id == senza.Id);
        Assert.Equal(0, player.GettoniConsumati);
        Assert.Equal(0, player.GettoniRimanenti);
        var att = await t.Db.MatchAttendances.SingleAsync(a => a.PlayerId == senza.Id);
        Assert.True(att.Presente);
        Assert.False(att.GettoneConsumato);
        var mov = await t.Db.TokenTransactions.SingleAsync(x => x.PlayerId == senza.Id);
        Assert.Equal(0, mov.Quantita);
        Assert.Contains("ESAURITI", mov.Motivazione);
    }

    [Fact]
    public async Task Annullare_la_presenza_restituisce_il_gettone()
    {
        using var t = new TestDb();
        var match = t.AddMatch();
        t.AddAttendance(match, t.Giocatore);
        var svc = t.Attendance();

        await svc.UpdateAttendanceAsync(match.Id, t.Giocatore.Id,
            new UpdateAttendanceDto { Presente = true, HaGiocato = true }, t.Admin.Id, t.Team.Id);
        await svc.UpdateAttendanceAsync(match.Id, t.Giocatore.Id,
            new UpdateAttendanceDto { Presente = false }, t.Admin.Id, t.Team.Id);

        var player = await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id);
        Assert.Equal(0, player.GettoniConsumati);
        var att = await t.Db.MatchAttendances.SingleAsync(a => a.PlayerId == player.Id);
        Assert.False(att.Presente);
        Assert.False(att.HaGiocato);
        Assert.False(att.GettoneConsumato);
        // Due movimenti: -1 e +1, il saldo dello storico torna a zero
        var movimenti = await t.Db.TokenTransactions.Where(x => x.PlayerId == player.Id).ToListAsync();
        Assert.Equal(2, movimenti.Count);
        Assert.Equal(0, movimenti.Sum(m => m.Quantita));
    }

    [Fact]
    public async Task Doppio_presente_non_consuma_due_volte()
    {
        using var t = new TestDb();
        var match = t.AddMatch();
        t.AddAttendance(match, t.Giocatore);
        var svc = t.Attendance();

        await svc.UpdateAttendanceAsync(match.Id, t.Giocatore.Id, new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);
        await svc.UpdateAttendanceAsync(match.Id, t.Giocatore.Id, new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id);

        var player = await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id);
        Assert.Equal(1, player.GettoniConsumati);
    }

    [Fact]
    public async Task Partita_conclusa_non_accetta_modifiche_alle_presenze()
    {
        using var t = new TestDb();
        var match = t.AddMatch(StatoPartita.Conclusa);
        t.AddAttendance(match, t.Giocatore);

        await Assert.ThrowsAsync<Exceptions.BusinessException>(() => t.Attendance().UpdateAttendanceAsync(
            match.Id, t.Giocatore.Id, new UpdateAttendanceDto { Presente = true }, t.Admin.Id, t.Team.Id));
    }
}
