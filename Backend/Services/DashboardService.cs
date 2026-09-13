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

        // Le prossime partite non concluse: la prima e' l'hero, tutte insieme sono il riepilogo personale
        var upcoming = await _context.Matches.Include(m => m.Convocations)
            .Where(m => m.TeamId == teamId && m.Stato != StatoPartita.Conclusa)
            .OrderBy(m => m.Data).ThenBy(m => m.Ora)
            .Take(5)
            .ToListAsync();
        var upcomingIds = upcoming.Select(m => m.Id).ToList();
        var mieDisponibilita = await _context.PlayerAvailabilities
            .Where(a => a.PlayerId == playerId && upcomingIds.Contains(a.MatchId))
            .ToDictionaryAsync(a => a.MatchId, a => a.Disponibile);

        MatchSummaryDto Summary(Models.Entities.Match m)
        {
            var mia = m.Convocations.FirstOrDefault(c => c.PlayerId == playerId);
            return new MatchSummaryDto
            {
                Id = m.Id, Data = m.Data, Ora = m.Ora.ToString(@"hh\:mm"),
                Luogo = m.Luogo, Titolo = m.Titolo, NumeroGiornata = m.NumeroGiornata, Stato = m.Stato.ToString(),
                Confermati = m.Convocations.Count(c => c.StatoRisposta == StatoRisposta.Confermato),
                InAttesa = m.Convocations.Count(c => c.StatoRisposta == StatoRisposta.InAttesa),
                NonDisponibili = m.Convocations.Count(c => c.StatoRisposta == StatoRisposta.NonDisponibile),
                MiaConvocazione = mia?.StatoRisposta.ToString(),
                MiaConvocazioneId = mia?.Id,
                MiaDisponibilita = mieDisponibilita.TryGetValue(m.Id, out var disp) ? disp : null,
                ConvocazioniInviate = m.Stato != StatoPartita.Programmata
            };
        }

        var miePartite = upcoming.Select(Summary).ToList();
        var matchSummary = miePartite.FirstOrDefault();

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
            ClassificaGettoni = useGettoni ? tokenSummary : new(),
            MiePartite = miePartite
        };
    }
}
