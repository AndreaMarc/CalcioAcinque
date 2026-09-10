using System.ComponentModel.DataAnnotations;

namespace CalcioAcinque.Backend.DTOs.Clubs;

public class ClubDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? InviteCode { get; set; }
    public DateTime CreatedAt { get; set; }
    public int TotaleMembri { get; set; }
    /// <summary>Vero se l'utente corrente e' admin in almeno una squadra della societa'.</summary>
    public bool IsAdmin { get; set; }

    // Dati per pagare, validi per tutte le squadre salvo override sulla singola
    public string? PaypalLink { get; set; }
    public string? Iban { get; set; }
    public string? IntestatarioIban { get; set; }

    public List<ClubTeamDto> Squadre { get; set; } = new();
}

public class ClubTeamDto
{
    public int Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public int GiocatoriInCampo { get; set; }
    public int TotaleGiocatori { get; set; }
    /// <summary>Player dell'utente corrente in questa squadra, null se non ne fa parte.</summary>
    public int? MioPlayerId { get; set; }
    public string? MioRuolo { get; set; }
}

public class ClubMemberDto
{
    public int Id { get; set; }
    public int ClubId { get; set; }
    public int? UserId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string? Soprannome { get; set; }
    public string? Telefono { get; set; }
    public DateTime? DataNascita { get; set; }
    public string? Note { get; set; }
    public string? Email { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<ClubMemberTeamDto> Squadre { get; set; } = new();
}

public class ClubMemberTeamDto
{
    public int TeamId { get; set; }
    public string TeamNome { get; set; } = string.Empty;
    public string Formato { get; set; } = string.Empty;
    public string FormatoLabel { get; set; } = string.Empty;
    public int PlayerId { get; set; }
    public string Ruolo { get; set; } = string.Empty;
    public string? Posizione { get; set; }
    public int? NumeroMaglia { get; set; }
    public int GettoniRimanenti { get; set; }
    public bool IscrizionePagata { get; set; }
    public bool TesseramentoPagato { get; set; }
}

public class CreateClubDto
{
    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;
}

public class UpdateClubDto
{
    [MaxLength(100)]
    public string? Nome { get; set; }

    /// <summary>Stringa vuota per cancellare il dato.</summary>
    [MaxLength(255)]
    public string? PaypalLink { get; set; }

    [MaxLength(34)]
    public string? Iban { get; set; }

    [MaxLength(100)]
    public string? IntestatarioIban { get; set; }
}

public class CreateClubTeamDto
{
    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    /// <summary>CalcioA5 | CalcioA7 | CalcioA8 | CalcioA11</summary>
    public string Formato { get; set; } = "CalcioA5";

    public int PartitePerStagione { get; set; } = 8;
    public bool UseGettoni { get; set; } = true;
    public int GettoniPerGiocatore { get; set; } = 4;

    public decimal QuotaIscrizione { get; set; }
    public decimal QuotaTesseramento { get; set; }
    public decimal CostoPartita { get; set; }

    /// <summary>Se vero, l'utente che crea la squadra ci entra come admin (default).</summary>
    public bool IscriviMi { get; set; } = true;
}

public class UpsertClubMemberDto
{
    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Soprannome { get; set; }

    [MaxLength(20)]
    public string? Telefono { get; set; }

    public DateTime? DataNascita { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    /// <summary>Opzionale: crea (o collega) l'account della persona. Serve per poterla
    /// iscrivere a una squadra.</summary>
    [EmailAddress, MaxLength(255)]
    public string? Email { get; set; }

    /// <summary>Password iniziale, usata solo se l'account non esiste ancora.</summary>
    [MinLength(6)]
    public string? Password { get; set; }
}

public class AssignMemberToTeamDto
{
    [Required]
    public int TeamId { get; set; }

    public string Ruolo { get; set; } = "User";
    public string? Posizione { get; set; }
    public int? NumeroMaglia { get; set; }
}

public class TeamFormatDto
{
    public string Valore { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public string ShortLabel { get; set; } = string.Empty;
    public int GiocatoriInCampo { get; set; }
    public int MaxConvocati { get; set; }
    public int MinutiPerTempo { get; set; }
    public int NumeroTempi { get; set; }
    public List<string> Posizioni { get; set; } = new();
}
