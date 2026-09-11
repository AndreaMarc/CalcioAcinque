using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Models.Entities;

[Table("teams")]
public class Team
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    /// <summary>Societa' di appartenenza. Null solo per squadre create prima dell'introduzione delle societa'.</summary>
    public int? ClubId { get; set; }

    [Required, MaxLength(100)]
    public string Nome { get; set; } = string.Empty;

    /// <summary>Disciplina della squadra: determina i default di regole e ruoli.</summary>
    public TeamFormat Formato { get; set; } = TeamFormat.CalcioA5;

    public int PartitePerStagione { get; set; } = 8;
    public int GettoniPerGiocatore { get; set; } = 4;
    public bool UseGettoni { get; set; } = true;

    // --- Regole di gioco (inizializzate dal preset del formato, poi modificabili) ---

    public int GiocatoriInCampo { get; set; } = 5;

    /// <summary>Massimo di convocati per partita. Null = nessun limite.</summary>
    public int? MaxConvocati { get; set; }

    public int MinutiPerTempo { get; set; } = 25;
    public int NumeroTempi { get; set; } = 2;

    // --- Costi (in euro, per giocatore) ---

    [Column(TypeName = "decimal(10,2)")]
    public decimal QuotaIscrizione { get; set; }

    [Column(TypeName = "decimal(10,2)")]
    public decimal QuotaTesseramento { get; set; }

    /// <summary>Costo di una singola partita, addebitato a chi paga a partita.</summary>
    [Column(TypeName = "decimal(10,2)")]
    public decimal CostoPartita { get; set; }

    /// <summary>Regime applicato ai giocatori che non ne hanno uno proprio.</summary>
    public RegimePagamento RegimePagamentoDefault { get; set; } = RegimePagamento.Stagionale;

    /// <summary>Chi deve la quota di iscrizione. Di norma e la quota stagionale, quindi non la devono i paga-a-partita.</summary>
    public DestinatariQuota ApplicaIscrizioneA { get; set; } = DestinatariQuota.SoloStagionali;

    /// <summary>Chi deve il tesseramento. Di norma tutti: e il cartellino, non dipende da come si paga.</summary>
    public DestinatariQuota ApplicaTesseramentoA { get; set; } = DestinatariQuota.Tutti;

    /// <summary>Minuti sotto i quali una partita non viene proposta per l addebito. 0 = nessuna soglia.</summary>
    public int MinutiMinimiPerAddebito { get; set; }

    /// <summary>Quante ore prima della partita mandare il promemoria. 0 = disattivato.</summary>
    public int OrePromemoriaPartita { get; set; } = 24;

    // --- Dati per pagare: se null valgono quelli della societa ---

    [MaxLength(255)]
    public string? PaypalLink { get; set; }

    [MaxLength(34)]
    public string? Iban { get; set; }

    [MaxLength(100)]
    public string? IntestatarioIban { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [MaxLength(20)]
    public string? InviteCode { get; set; }

    /// <summary>
    /// Logo della squadra come data-URL/base64 (PNG o JPEG, gia' ridotto dal client).
    /// Sta sul server cosi' lo vedono tutti i membri, non solo il browser che l'ha caricato.
    /// </summary>
    public string? LogoBase64 { get; set; }

    [NotMapped]
    public TeamFormatPreset Preset => TeamFormats.Preset(Formato);

    [ForeignKey("ClubId")]
    public virtual Club? Club { get; set; }

    public virtual ICollection<Player> Players { get; set; } = new List<Player>();
    public virtual ICollection<Match> Matches { get; set; } = new List<Match>();
    public virtual ICollection<PendingPlayer> PendingPlayers { get; set; } = new List<PendingPlayer>();
    public virtual ICollection<Season> Seasons { get; set; } = new List<Season>();

    /// <summary>Applica i default del formato alle regole di gioco (usato alla creazione e al cambio formato).</summary>
    public void ApplyFormatDefaults()
    {
        var preset = TeamFormats.Preset(Formato);
        GiocatoriInCampo = preset.GiocatoriInCampo;
        MaxConvocati = preset.MaxConvocati;
        MinutiPerTempo = preset.MinutiPerTempo;
        NumeroTempi = preset.NumeroTempi;
    }
}
