namespace CalcioAcinque.Backend.Models.Enums;

/// <summary>
/// Categorie delle uscite di cassa. Persistite come stringa: aggiungere in coda.
/// </summary>
public enum CategoriaSpesa
{
    Campo = 0,
    Arbitro = 1,
    Materiale = 2,
    Trasferta = 3,
    Altro = 4
}

public static class CategorieSpesa
{
    public static string Label(CategoriaSpesa c) => c switch
    {
        CategoriaSpesa.Campo => "Affitto campo",
        CategoriaSpesa.Arbitro => "Arbitro",
        CategoriaSpesa.Materiale => "Materiale",
        CategoriaSpesa.Trasferta => "Trasferta",
        _ => "Altro"
    };
}
