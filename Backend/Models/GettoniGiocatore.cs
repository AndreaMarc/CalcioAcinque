using CalcioAcinque.Backend.Models.Entities;

namespace CalcioAcinque.Backend.Models;

/// <summary>
/// Gettoni di un singolo giocatore: la squadra decide il default, il giocatore
/// puo' avere un'eccezione (gettoni solo per lui, o un numero diverso a stagione).
/// E' il punto unico in cui si risolve questa ereditarieta', come
/// RegimiPagamento.Effettivo per il regime.
/// </summary>
public static class GettoniGiocatore
{
    public static bool Attivi(Player player, Team team) => player.UsaGettoni ?? team.UseGettoni;

    public static int PerStagione(Player player, Team team) =>
        player.GettoniPerStagione ?? team.GettoniPerGiocatore;

    /// <summary>Gettoni da dare a inizio stagione (o all'ingresso in squadra).</summary>
    public static int Iniziali(Player player, Team team) =>
        Attivi(player, team) ? PerStagione(player, team) : 0;
}
