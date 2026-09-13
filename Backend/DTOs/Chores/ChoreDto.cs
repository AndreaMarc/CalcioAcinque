using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Chores;

public class TeamChoreDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public bool Attivo { get; set; }
    public int Ordine { get; set; }
}

public class UpsertChoreDto
{
    [Required, MaxLength(60)]
    public string Nome { get; set; } = string.Empty;

    public bool? Attivo { get; set; }
}

public class MatchChoreDto
{
    public int ChoreId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public int? PlayerId { get; set; }
    public string? NomeGiocatore { get; set; }
    public string? Soprannome { get; set; }
}

public class SetChoreDto
{
    /// <summary>Null per liberare il turno.</summary>
    public int? PlayerId { get; set; }
}
