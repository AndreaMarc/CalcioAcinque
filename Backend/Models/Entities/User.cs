using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("users")]
public class User
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required, MaxLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    /// Tema scuro scelto dall'utente, uguale su tutti i suoi dispositivi.
    /// null = mai scelto: ogni dispositivo tiene la sua preferenza locale.
    /// </summary>
    public bool? TemaScuro { get; set; }

    /// <summary>
    /// Colore brand scelto dall'utente come "#RRGGBB", uguale su tutti i suoi
    /// dispositivi. null = mai scelto (resta la preferenza locale, o il verde InCampo).
    /// </summary>
    [MaxLength(7)]
    public string? ColoreBrand { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public virtual ICollection<Player> Players { get; set; } = new List<Player>();
    public virtual ICollection<ClubMember> ClubMemberships { get; set; } = new List<ClubMember>();
    public virtual ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public virtual ICollection<TeamDraft> TeamDrafts { get; set; } = new List<TeamDraft>();
}
