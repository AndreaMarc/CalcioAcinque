using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Auth;

public class SignupRequest
{
    [Required, EmailAddress, MaxLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(6), MaxLength(100)]
    public string Password { get; set; } = string.Empty;
}
