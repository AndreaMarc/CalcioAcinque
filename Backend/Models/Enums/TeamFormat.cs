namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>Disciplina/formato della squadra. Il valore numerico e' il numero di giocatori in campo.</summary>
public enum TeamFormat
{
    CalcioA5 = 5,
    CalcioA7 = 7,
    CalcioA8 = 8,
    CalcioA11 = 11
}

/// <summary>Valori di default (sovrascrivibili sul Team) associati a ogni formato.</summary>
public record TeamFormatPreset(
    TeamFormat Formato,
    string Label,
    string ShortLabel,
    int GiocatoriInCampo,
    int MaxConvocati,
    int MinutiPerTempo,
    int NumeroTempi,
    IReadOnlyList<PlayerPosition> Posizioni);

public static class TeamFormats
{
    private static readonly Dictionary<TeamFormat, TeamFormatPreset> Presets = new()
    {
        [TeamFormat.CalcioA5] = new(
            TeamFormat.CalcioA5, "Calcio a 5", "A5",
            GiocatoriInCampo: 5, MaxConvocati: 12, MinutiPerTempo: 25, NumeroTempi: 2,
            Posizioni: new[]
            {
                PlayerPosition.Portiere, PlayerPosition.Difensore, PlayerPosition.Laterale,
                PlayerPosition.Centrale, PlayerPosition.Pivot, PlayerPosition.Universale,
                PlayerPosition.Jolly
            }),
        [TeamFormat.CalcioA7] = new(
            TeamFormat.CalcioA7, "Calcio a 7", "A7",
            GiocatoriInCampo: 7, MaxConvocati: 14, MinutiPerTempo: 30, NumeroTempi: 2,
            Posizioni: new[]
            {
                PlayerPosition.Portiere, PlayerPosition.Difensore, PlayerPosition.Terzino,
                PlayerPosition.Mediano, PlayerPosition.Centrocampista, PlayerPosition.Esterno,
                PlayerPosition.Ala, PlayerPosition.Attaccante, PlayerPosition.Jolly
            }),
        [TeamFormat.CalcioA8] = new(
            TeamFormat.CalcioA8, "Calcio a 8", "A8",
            GiocatoriInCampo: 8, MaxConvocati: 16, MinutiPerTempo: 30, NumeroTempi: 2,
            Posizioni: new[]
            {
                PlayerPosition.Portiere, PlayerPosition.Difensore, PlayerPosition.Terzino,
                PlayerPosition.Mediano, PlayerPosition.Centrocampista, PlayerPosition.Esterno,
                PlayerPosition.Ala, PlayerPosition.Attaccante, PlayerPosition.Jolly
            }),
        [TeamFormat.CalcioA11] = new(
            TeamFormat.CalcioA11, "Calcio a 11", "A11",
            GiocatoriInCampo: 11, MaxConvocati: 20, MinutiPerTempo: 45, NumeroTempi: 2,
            Posizioni: new[]
            {
                PlayerPosition.Portiere, PlayerPosition.Terzino, PlayerPosition.Difensore,
                PlayerPosition.Libero, PlayerPosition.Mediano, PlayerPosition.Centrocampista,
                PlayerPosition.Trequartista, PlayerPosition.Esterno, PlayerPosition.Ala,
                PlayerPosition.Attaccante, PlayerPosition.Punta, PlayerPosition.Jolly
            })
    };

    public static TeamFormatPreset Preset(TeamFormat formato) =>
        Presets.TryGetValue(formato, out var p) ? p : Presets[TeamFormat.CalcioA5];

    public static IEnumerable<TeamFormatPreset> All => Presets.Values;

    public static string Label(TeamFormat formato) => Preset(formato).Label;

    /// <summary>Vero se la posizione ha senso nel formato indicato.</summary>
    public static bool SupportsPosition(TeamFormat formato, PlayerPosition posizione) =>
        Preset(formato).Posizioni.Contains(posizione);
}
