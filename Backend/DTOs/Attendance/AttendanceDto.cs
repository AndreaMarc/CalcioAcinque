namespace CalcioAcinque.Backend.DTOs.Attendance;

public class MatchAttendanceDto
{
    public int Id { get; set; }
    public int MatchId { get; set; }
    public int PlayerId { get; set; }
    public string NomeGiocatore { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public bool Convocato { get; set; }
    public bool Presente { get; set; }
    public bool HaGiocato { get; set; }
    public bool GettoneConsumato { get; set; }
    public int GettoniRimanenti { get; set; }

    // Statistiche facoltative
    public int? MinutiGiocati { get; set; }
    public int? Goal { get; set; }
    public int? Assist { get; set; }
    public int? Autogoal { get; set; }
    public int? Ammonizioni { get; set; }
    public int? Espulsioni { get; set; }
    public int? GoalSubiti { get; set; }
}

public class UpdateAttendanceDto
{
    public bool? Presente { get; set; }
    public bool? HaGiocato { get; set; }

    // Statistiche facoltative - usano wrapper per distinguere "non inviato" da "azzerato"
    public int? MinutiGiocati { get; set; }
    public int? Goal { get; set; }
    public int? Assist { get; set; }
    public int? Autogoal { get; set; }
    public int? Ammonizioni { get; set; }
    public int? Espulsioni { get; set; }
    public int? GoalSubiti { get; set; }
}
