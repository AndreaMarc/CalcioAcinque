using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Models.Enums;
using Microsoft.EntityFrameworkCore;

namespace CalcioAcinque.Backend.Tests;

public class PartitaStatoTests
{
    [Fact]
    public async Task Una_partita_conclusa_si_riapre_solo_verso_in_corso()
    {
        using var t = new TestDb();
        var match = t.AddMatch(StatoPartita.Conclusa);
        var svc = t.Matches();

        await Assert.ThrowsAsync<Exceptions.BadRequestException>(
            () => svc.UpdateStatoAsync(t.Team.Id, match.Id, StatoPartita.Programmata));

        var dto = await svc.UpdateStatoAsync(t.Team.Id, match.Id, StatoPartita.InCorso);
        Assert.Equal("InCorso", dto.Stato);
    }

    [Fact]
    public async Task Il_ciclo_normale_e_ammesso()
    {
        using var t = new TestDb();
        var match = t.AddMatch(StatoPartita.Programmata);
        var svc = t.Matches();

        await svc.UpdateStatoAsync(t.Team.Id, match.Id, StatoPartita.ConvocazioniInviate);
        await svc.UpdateStatoAsync(t.Team.Id, match.Id, StatoPartita.InCorso);
        var dto = await svc.UpdateStatoAsync(t.Team.Id, match.Id, StatoPartita.Conclusa);
        Assert.Equal("Conclusa", dto.Stato);
    }

    [Fact]
    public async Task Una_partita_di_un_altra_squadra_non_si_tocca()
    {
        using var t = new TestDb();
        var match = t.AddMatch();
        await Assert.ThrowsAsync<Exceptions.NotFoundException>(
            () => t.Matches().UpdateStatoAsync(t.Team.Id + 99, match.Id, StatoPartita.Conclusa));
    }
}

public class RuoliTests
{
    [Fact]
    public async Task L_unico_admin_non_puo_essere_declassato()
    {
        using var t = new TestDb();
        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Players().UpdateAsync(t.Team.Id, t.Admin.Id, new UpdatePlayerDto { Ruolo = "User" }));

        var admin = await t.Db.Players.SingleAsync(p => p.Id == t.Admin.Id);
        Assert.Equal(UserRole.Admin, admin.Ruolo);
    }

    [Fact]
    public async Task Con_due_admin_il_declassamento_passa()
    {
        using var t = new TestDb();
        t.AddPlayer("Vice", UserRole.Admin);

        var dto = await t.Players().UpdateAsync(t.Team.Id, t.Admin.Id, new UpdatePlayerDto { Ruolo = "Mister" });
        Assert.Equal("Mister", dto.Ruolo);
    }

    [Fact]
    public async Task L_unico_admin_non_puo_essere_eliminato()
    {
        using var t = new TestDb();
        await Assert.ThrowsAsync<Exceptions.BusinessException>(
            () => t.Players().DeleteAsync(t.Team.Id, t.Admin.Id));
    }
}
