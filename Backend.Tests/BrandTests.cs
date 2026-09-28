using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

namespace CalcioAcinque.Backend.Tests;

/// <summary>Colore e tema sono dell'account: ogni dispositivo li rilegge da qui.</summary>
public class BrandTests
{
    private static AuthService Auth(TestDb t) =>
        new(t.Db, new ConfigurationBuilder().Build(), NullLogger<AuthService>.Instance);

    [Fact]
    public async Task Colore_e_tema_si_salvano_sull_utente_e_null_non_tocca_nulla()
    {
        using var t = new TestDb();
        var userId = t.Giocatore.UserId;

        await Auth(t).UpdatePreferencesAsync(userId, new UpdatePreferencesRequest { ColoreBrand = "#3b7cf2", TemaScuro = true });
        var user = await t.Db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
        Assert.Equal("#3B7CF2", user.ColoreBrand);
        Assert.True(user.TemaScuro);

        await Auth(t).UpdatePreferencesAsync(userId, new UpdatePreferencesRequest { TemaScuro = false });
        user = await t.Db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
        Assert.Equal("#3B7CF2", user.ColoreBrand);
        Assert.False(user.TemaScuro);

        // "" = scelta esplicita del verde di default, diversa da "mai scelto"
        await Auth(t).UpdatePreferencesAsync(userId, new UpdatePreferencesRequest { ColoreBrand = "" });
        user = await t.Db.Users.AsNoTracking().SingleAsync(u => u.Id == userId);
        Assert.Equal("", user.ColoreBrand);
    }

    [Theory]
    [InlineData("3B7CF2")]
    [InlineData("#3B7CF")]
    [InlineData("#GGGGGG")]
    [InlineData("#3B7CF2FF")]
    public async Task Un_colore_malformato_viene_rifiutato(string colore)
    {
        using var t = new TestDb();
        await Assert.ThrowsAsync<Exceptions.BadRequestException>(
            () => Auth(t).UpdatePreferencesAsync(t.Giocatore.UserId, new UpdatePreferencesRequest { ColoreBrand = colore }));
    }
}
