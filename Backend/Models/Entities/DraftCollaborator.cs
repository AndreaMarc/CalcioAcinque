using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("draft_collaborators")]
public class DraftCollaborator
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    public int TeamDraftId { get; set; }
    public int UserId { get; set; }

    public bool IsOwner { get; set; } = false;

    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("TeamDraftId")]
    public virtual TeamDraft TeamDraft { get; set; } = null!;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;
}
