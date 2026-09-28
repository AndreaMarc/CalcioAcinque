using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Teams;
using CalcioAcinque.Backend.Exceptions;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface ITeamService
{
    Task<TeamDto> GetByIdAsync(int teamId);
    Task<TeamDto> UpdateAsync(int teamId, UpdateTeamDto dto);
}

public class TeamService : ITeamService
{
    private readonly ApplicationDbContext _context;

    public TeamService(ApplicationDbContext context) { _context = context; }

    public async Task<TeamDto> GetByIdAsync(int teamId)
    {
        var team = await _context.Teams
            .Include(t => t.Players)
            .Include(t => t.Club)
            .FirstOrDefaultAsync(t => t.Id == teamId);
        if (team == null) throw new NotFoundException("Team", teamId);
        return MapToDto(team);
    }

    public async Task<TeamDto> UpdateAsync(int teamId, UpdateTeamDto dto)
    {
        var team = await _context.Teams
            .Include(t => t.Players)
            .Include(t => t.Club)
            .FirstOrDefaultAsync(t => t.Id == teamId);
        if (team == null) throw new NotFoundException("Team", teamId);

        if (dto.Nome != null) team.Nome = dto.Nome;

        // Il cambio di formato riallinea le regole ai default della nuova disciplina;
        // eventuali override passati nella stessa richiesta vengono applicati dopo.
        if (dto.Formato != null)
        {
            var nuovoFormato = ClubService.ParseFormat(dto.Formato);
            if (nuovoFormato != team.Formato)
            {
                team.Formato = nuovoFormato;
                team.ApplyFormatDefaults();
                await ClearIncompatiblePositionsAsync(team);
            }
        }

        if (dto.PartitePerStagione.HasValue) team.PartitePerStagione = dto.PartitePerStagione.Value;
        if (dto.GettoniPerGiocatore.HasValue) team.GettoniPerGiocatore = dto.GettoniPerGiocatore.Value;
        if (dto.UseGettoni.HasValue) team.UseGettoni = dto.UseGettoni.Value;

        if (dto.GiocatoriInCampo.HasValue)
        {
            if (dto.GiocatoriInCampo.Value is < 3 or > 11)
                throw new BadRequestException("I giocatori in campo devono essere tra 3 e 11");
            team.GiocatoriInCampo = dto.GiocatoriInCampo.Value;
        }

        if (dto.MaxConvocati.HasValue)
        {
            // 0 = nessun limite
            if (dto.MaxConvocati.Value < 0)
                throw new BadRequestException("Il numero massimo di convocati non può essere negativo");
            if (dto.MaxConvocati.Value > 0 && dto.MaxConvocati.Value < team.GiocatoriInCampo)
                throw new BadRequestException("I convocati non possono essere meno dei giocatori in campo");
            team.MaxConvocati = dto.MaxConvocati.Value == 0 ? null : dto.MaxConvocati.Value;
        }

        if (dto.MinutiPerTempo.HasValue)
        {
            if (dto.MinutiPerTempo.Value is < 1 or > 60)
                throw new BadRequestException("I minuti per tempo devono essere tra 1 e 60");
            team.MinutiPerTempo = dto.MinutiPerTempo.Value;
        }

        if (dto.NumeroTempi.HasValue)
        {
            if (dto.NumeroTempi.Value is < 1 or > 4)
                throw new BadRequestException("Il numero di tempi deve essere tra 1 e 4");
            team.NumeroTempi = dto.NumeroTempi.Value;
        }

        if (dto.RegimePagamentoDefault != null &&
            Enum.TryParse<RegimePagamento>(dto.RegimePagamentoDefault, true, out var regime))
            team.RegimePagamentoDefault = regime;

        if (dto.ApplicaIscrizioneA != null &&
            Enum.TryParse<DestinatariQuota>(dto.ApplicaIscrizioneA, true, out var destIscr))
            team.ApplicaIscrizioneA = destIscr;

        if (dto.ApplicaTesseramentoA != null &&
            Enum.TryParse<DestinatariQuota>(dto.ApplicaTesseramentoA, true, out var destTess))
            team.ApplicaTesseramentoA = destTess;

        if (dto.MinutiMinimiPerAddebito.HasValue)
        {
            if (dto.MinutiMinimiPerAddebito.Value < 0)
                throw new BadRequestException("I minuti minimi non possono essere negativi");
            team.MinutiMinimiPerAddebito = dto.MinutiMinimiPerAddebito.Value;
        }

        if (dto.OrePromemoriaPartita.HasValue)
        {
            if (dto.OrePromemoriaPartita.Value is < 0 or > 168)
                throw new BadRequestException("Le ore di preavviso devono essere tra 0 e 168");
            team.OrePromemoriaPartita = dto.OrePromemoriaPartita.Value;
        }

        // Stringa vuota = azzera l override e torna ai dati della societa
        if (dto.PaypalLink != null) team.PaypalLink = Vuoto(dto.PaypalLink);
        if (dto.Iban != null) team.Iban = Vuoto(dto.Iban)?.Replace(" ", string.Empty).ToUpperInvariant();
        if (dto.IntestatarioIban != null) team.IntestatarioIban = Vuoto(dto.IntestatarioIban);

        if (dto.LogoBase64 != null)
        {
            // ~300 KB di immagine: il client la ridimensiona prima, questo e' il paracadute
            if (dto.LogoBase64.Length > 400_000)
                throw new BadRequestException("Il logo è troppo grande: massimo 300 KB");
            team.LogoBase64 = Vuoto(dto.LogoBase64);
        }

        if (dto.QuotaIscrizione.HasValue) team.QuotaIscrizione = RequireNonNegative(dto.QuotaIscrizione.Value, "La quota di iscrizione");
        if (dto.QuotaTesseramento.HasValue) team.QuotaTesseramento = RequireNonNegative(dto.QuotaTesseramento.Value, "La quota di tesseramento");
        if (dto.CostoPartita.HasValue) team.CostoPartita = RequireNonNegative(dto.CostoPartita.Value, "Il costo partita");

        await _context.SaveChangesAsync();
        return MapToDto(team);
    }

    private static string? Vuoto(string value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static decimal RequireNonNegative(decimal value, string label)
    {
        if (value < 0) throw new BadRequestException($"{label} non può essere negativa");
        return value;
    }

    /// <summary>Azzera i ruoli in campo non previsti dal nuovo formato (es. Pivot passando da a5 ad a7).</summary>
    private async Task ClearIncompatiblePositionsAsync(Team team)
    {
        var players = team.Players.Count > 0
            ? team.Players.ToList()
            : await _context.Players.Where(p => p.TeamId == team.Id).ToListAsync();

        foreach (var player in players)
        {
            if (player.Posizione.HasValue && !TeamFormats.SupportsPosition(team.Formato, player.Posizione.Value))
                player.Posizione = null;
        }
    }

    private static TeamDto MapToDto(Team team)
    {
        var preset = TeamFormats.Preset(team.Formato);
        return new TeamDto
        {
            Id = team.Id,
            ClubId = team.ClubId,
            ClubNome = team.Club?.Nome,
            Nome = team.Nome,
            Formato = team.Formato.ToString(),
            FormatoLabel = preset.Label,
            FormatoShortLabel = preset.ShortLabel,
            PartitePerStagione = team.PartitePerStagione,
            GettoniPerGiocatore = team.GettoniPerGiocatore,
            UseGettoni = team.UseGettoni,
            GiocatoriInCampo = team.GiocatoriInCampo,
            MaxConvocati = team.MaxConvocati,
            MinutiPerTempo = team.MinutiPerTempo,
            NumeroTempi = team.NumeroTempi,
            QuotaIscrizione = team.QuotaIscrizione,
            QuotaTesseramento = team.QuotaTesseramento,
            CostoPartita = team.CostoPartita,
            RegimePagamentoDefault = team.RegimePagamentoDefault.ToString(),
            ApplicaIscrizioneA = team.ApplicaIscrizioneA.ToString(),
            ApplicaTesseramentoA = team.ApplicaTesseramentoA.ToString(),
            MinutiMinimiPerAddebito = team.MinutiMinimiPerAddebito,
            OrePromemoriaPartita = team.OrePromemoriaPartita,
            PaypalLink = team.PaypalLink,
            Iban = team.Iban,
            IntestatarioIban = team.IntestatarioIban,
            // La squadra vince sulla societa solo se ha un valore proprio
            PaypalLinkEffettivo = team.PaypalLink ?? team.Club?.PaypalLink,
            IbanEffettivo = team.Iban ?? team.Club?.Iban,
            IntestatarioIbanEffettivo = team.IntestatarioIban ?? team.Club?.IntestatarioIban,
            TotaleGiocatori = team.Players?.Count ?? 0,
            CreatedAt = team.CreatedAt,
            LogoBase64 = team.LogoBase64
        };
    }
}
