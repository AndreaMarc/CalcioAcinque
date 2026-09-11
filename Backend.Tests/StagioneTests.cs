using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.DTOs.Seasons;
using CalcioAcinque.Backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

/// <summary>La chiusura stagione non e' annullabile dall'app: meglio provarla qui.</summary>
public class StagioneTests
{
    [Fact]
    public async Task Con_arretrati_la_chiusura_si_ferma_a_meno_di_condonare()
    {
        using var t = new TestDb();
        await t.Payments().GenerateFeesAsync(t.Team.Id, new GenerateFeesDto(), t.Admin.Id);

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto(), t.Admin.Id));

        var result = await t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto { IgnoraArretrati = true }, t.Admin.Id);
        Assert.Equal(240m, result.ArretratiLasciatiAperti);
    }

    [Fact]
    public async Task La_chiusura_azzera_gettoni_e_quote_e_apre_una_stagione_nuova()
    {
        using var t = new TestDb();
        // Stato sporco di fine stagione: gettoni consumati e quote pagate
        t.Giocatore.GettoniConsumati = 3;
        t.Giocatore.IscrizionePagata = true;
        t.Giocatore.TesseramentoPagato = true;
        await t.Db.SaveChangesAsync();
        var vecchia = await t.Seasons().GetOrCreateCorrenteAsync(t.Team.Id);

        var result = await t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto { NomeNuovaStagione = "2027/28" }, t.Admin.Id);

        Assert.Equal("2027/28", result.StagioneNuova);
        Assert.Equal(2, result.GiocatoriAzzerati);
        var chiusa = await t.Db.Seasons.SingleAsync(s => s.Id == vecchia.Id);
        Assert.True(chiusa.Chiusa);
        Assert.NotNull(chiusa.DataFine);
        var aperta = await t.Seasons().GetCorrenteAsync(t.Team.Id);
        Assert.NotNull(aperta);
        Assert.Equal("2027/28", aperta!.Nome);

        var player = await t.Db.Players.SingleAsync(p => p.Id == t.Giocatore.Id);
        Assert.Equal(0, player.GettoniConsumati);
        Assert.Equal(t.Team.GettoniPerGiocatore, player.GettoniTotali);
        Assert.False(player.IscrizionePagata);
        Assert.False(player.TesseramentoPagato);
        // La ricarica lascia traccia nello storico
        Assert.True(await t.Db.TokenTransactions.AnyAsync(x => x.PlayerId == player.Id && x.Quantita == t.Team.GettoniPerGiocatore));
    }

    [Fact]
    public async Task Un_nome_di_stagione_gia_usato_viene_rifiutato()
    {
        using var t = new TestDb();
        var corrente = await t.Seasons().GetOrCreateCorrenteAsync(t.Team.Id);

        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Seasons().CloseAsync(t.Team.Id, new CloseSeasonDto { NomeNuovaStagione = corrente.Nome }, t.Admin.Id));
    }
}
