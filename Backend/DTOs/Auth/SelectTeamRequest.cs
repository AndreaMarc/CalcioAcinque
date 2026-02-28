using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class SelectTeamRequest
{
    [Required]
    public int TeamId { get; set; }
}
