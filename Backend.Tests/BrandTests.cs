using CalcioAcinque.Backend.DTOs.Teams;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Tests;

/// <summary>Il colore brand sta sul server: tutti i membri e dispositivi lo leggono da qui.</summary>
public class BrandTests
{
    [Fact]
    public async Task Il_colore_si_salva_normalizzato_e_si_azzera_con_stringa_vuota()
    {
        using var t = new TestDb();
        var teams = new TeamService(t.Db);

        var dto = await teams.UpdateAsync(t.Team.Id, new UpdateTeamDto { ColoreBrand = "#3b7cf2" });
        Assert.Equal("#3B7CF2", dto.ColoreBrand);
        Assert.Equal("#3B7CF2", (await teams.GetByIdAsync(t.Team.Id)).ColoreBrand);

        // null = non toccare
        dto = await teams.UpdateAsync(t.Team.Id, new UpdateTeamDto { Nome = "Altro" });
        Assert.Equal("#3B7CF2", dto.ColoreBrand);

        dto = await teams.UpdateAsync(t.Team.Id, new UpdateTeamDto { ColoreBrand = "" });
        Assert.Null(dto.ColoreBrand);
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
            () => new TeamService(t.Db).UpdateAsync(t.Team.Id, new UpdateTeamDto { ColoreBrand = colore }));
    }
}
