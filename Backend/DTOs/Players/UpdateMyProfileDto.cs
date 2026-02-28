using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Players;

public class UpdateMyProfileDto
{
    [MaxLength(100)]
    public string? Nome { get; set; }

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }
}
