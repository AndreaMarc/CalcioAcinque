namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>
/// Ruoli in campo. Persistito come stringa: i nuovi valori vanno aggiunti in coda,
/// e i valori numerici esistenti non vanno mai rinumerati.
/// Quali ruoli siano proponibili dipende dal formato della squadra: vedi <see cref="TeamFormats"/>.
/// </summary>
public enum PlayerPosition
{
    Portiere = 0,
    Difensore = 1,
    Centrocampista = 2,
    Attaccante = 3,
    Jolly = 4,
    Esterno = 5,
    // Calcio a 5
    Laterale = 6,
    Centrale = 7,
    Pivot = 8,
    Universale = 9,
    // Calcio a 7 / 8 / 11
    Terzino = 10,
    Libero = 11,
    Mediano = 12,
    Trequartista = 13,
    Ala = 14,
    Punta = 15
}
