using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Dashboard;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Services;

public interface IDashboardService
{
    Task<DashboardDto> GetDashboardAsync(int teamId, int playerId);
}

public class DashboardService : IDashboardService
{
    private readonly ApplicationDbContext _context;
    public DashboardService(ApplicationDbContext context) { _context = context; }

    public async Task<DashboardDto> GetDashboardAsync(int teamId, int playerId)
    {
        var team = await _context.Teams.Include(t => t.Club).FirstOrDefaultAsync(t => t.Id == teamId);
        var useGettoni = team?.UseGettoni ?? true;
        var player = await _context.Players.FindAsync(playerId);

        var nextMatch = await _context.Matches.Include(m => m.Convocations)
            .Where(m => m.TeamId == teamId && m.Stato != StatoPartita.Conclusa)
            .OrderBy(m => m.Data).FirstOrDefaultAsync();

        MatchSummaryDto? matchSummary = null;
        if (nextMatch != null)
        {
            matchSummary = new MatchSummaryDto
            {
                Id = nextMatch.Id, Data = nextMatch.Data, Ora = nextMatch.Ora.ToString(@"hh\:mm"),
                Luogo = nextMatch.Luogo, Titolo = nextMatch.Titolo, NumeroGiornata = nextMatch.NumeroGiornata, Stato = nextMatch.Stato.ToString(),
                Confermati = nextMatch.Convocations.Count(c => c.StatoRisposta == StatoRisposta.Confermato),
                InAttesa = nextMatch.Convocations.Count(c => c.StatoRisposta == StatoRisposta.InAttesa),
                NonDisponibili = nextMatch.Convocations.Count(c => c.StatoRisposta == StatoRisposta.NonDisponibile),
                MiaConvocazione = nextMatch.Convocations.FirstOrDefault(c => c.PlayerId == playerId)?.StatoRisposta.ToString()
            };
        }

        var pendingConvocations = await _context.Convocations
            .CountAsync(c => c.PlayerId == playerId && c.StatoRisposta == StatoRisposta.InAttesa);
        var totalMatches = await _context.Matches.CountAsync(m => m.TeamId == teamId);
        var playedMatches = await _context.Matches.CountAsync(m => m.TeamId == teamId && m.Stato == StatoPartita.Conclusa);

        var tokenSummary = await _context.Players.Where(p => p.TeamId == teamId)
            .OrderByDescending(p => p.GettoniTotali - p.GettoniConsumati)
            .Select(p => new PlayerTokenSummaryForDashboard
            {
                PlayerId = p.Id, Nome = p.Nome, Soprannome = p.Soprannome,
                GettoniRimanenti = p.GettoniTotali - p.GettoniConsumati, GettoniTotali = p.GettoniTotali
            }).ToListAsync();

        var preset = TeamFormats.Preset(team?.Formato ?? TeamFormat.CalcioA5);

        return new DashboardDto
        {
            ProssimaPartita = matchSummary,
            UseGettoni = useGettoni,
            TeamNome = team?.Nome ?? string.Empty,
            Formato = (team?.Formato ?? TeamFormat.CalcioA5).ToString(),
            FormatoLabel = preset.Label,
            FormatoShortLabel = preset.ShortLabel,
            GiocatoriInCampo = team?.GiocatoriInCampo ?? preset.GiocatoriInCampo,
            MaxConvocati = team?.MaxConvocati,
            ClubId = team?.ClubId,
            ClubNome = team?.Club?.Nome,
            GettoniRimanenti = useGettoni ? (player?.GettoniRimanenti ?? 0) : 0,
            GettoniTotali = useGettoni ? (player?.GettoniTotali ?? 0) : 0,
            ConvocazioniInAttesa = pendingConvocations,
            PartiteGiocate = playedMatches,
            PartiteTotali = totalMatches,
            ClassificaGettoni = useGettoni ? tokenSummary : new()
        };
    }
}
