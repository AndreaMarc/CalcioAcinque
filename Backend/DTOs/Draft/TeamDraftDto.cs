namespace CalcioAcinque.Backend.DTOs.Draft;

public class TeamDraftDto
{
    public int Id { get; set; }
    public string NomeTeam { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public int PartitePerStagione { get; set; }
    public int GettoniPerGiocatore { get; set; }
    public bool UseGettoni { get; set; }
    public string ShareCode { get; set; } = string.Empty;
    public bool IsOwner { get; set; }
    public int OwnerUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<DraftCandidateDto> Candidates { get; set; } = new();
    public List<DraftCollaboratorDto> Collaborators { get; set; } = new();
}

public class DraftCandidateDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Posizione { get; set; }
    public string Stato { get; set; } = string.Empty;
    public int Bravura { get; set; }
    public int Affidabilita { get; set; }
    public bool Tesserato { get; set; }
    public bool IsFriend { get; set; }
    public string? Note { get; set; }
}

public class AddFriendsRequest
{
    public int Count { get; set; } = 1;
}

public class DraftCollaboratorDto
{
    public int UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public bool IsOwner { get; set; }
    public DateTime JoinedAt { get; set; }
}

public class DraftPreviewDto
{
    public int Id { get; set; }
    public string NomeTeam { get; set; } = string.Empty;
    public string OwnerEmail { get; set; } = string.Empty;
    public int CandidatesCount { get; set; }
    public int CollaboratorsCount { get; set; }
}
