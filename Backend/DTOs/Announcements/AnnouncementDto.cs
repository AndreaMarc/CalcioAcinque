namespace CalcioAcinque.Backend.DTOs.Announcements;

public class AnnouncementDto
{
    public int Id { get; set; }
    public int TeamId { get; set; }
    public int? AuthorId { get; set; }
    public string AutoreNome { get; set; } = string.Empty;
    public string? AutoreSoprannome { get; set; }
    public string Titolo { get; set; } = string.Empty;
    public string Contenuto { get; set; } = string.Empty;
    public bool Importante { get; set; }
    public DateTime CreatedAt { get; set; }
    public int TotalePresaVisione { get; set; }
    public int TotaleGiocatori { get; set; }
    public bool HoPresaVisione { get; set; }
}

public class AnnouncementDetailDto : AnnouncementDto
{
    public List<AnnouncementReadDto> PresaVisione { get; set; } = new();
}

public class AnnouncementReadDto
{
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public DateTime ReadAt { get; set; }
}

public class CreateAnnouncementDto
{
    public string Titolo { get; set; } = string.Empty;
    public string Contenuto { get; set; } = string.Empty;
    public bool Importante { get; set; } = false;
}
