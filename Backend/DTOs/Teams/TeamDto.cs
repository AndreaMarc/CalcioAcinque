namespace CalcioAcinque.Backend.DTOs.Teams;

public class TeamDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public int PartitePerStagione { get; set; }
    public int GettoniPerGiocatore { get; set; }
    public bool UseGettoni { get; set; }
    public int TotaleGiocatori { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CreateTeamDto
{
    public string Nome { get; set; } = string.Empty;
    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;
}

public class UpdateTeamDto
{
    public string? Nome { get; set; }
    public int? PartitePerStagione { get; set; }
    public int? GettoniPerGiocatore { get; set; }
    public bool? UseGettoni { get; set; }
}
