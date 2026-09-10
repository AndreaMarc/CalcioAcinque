using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Matches;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/teams/{teamId}/[controller]")]
[Authorize]
public class MatchesController : ControllerBase
{
    private readonly IMatchService _matchService;
    private readonly ApplicationDbContext _context;

    public MatchesController(IMatchService matchService, ApplicationDbContext context)
    {
        _matchService = matchService;
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<MatchDto>>>> GetAll(
        int teamId, [FromQuery] string? stato = null, [FromQuery] int? seasonId = null)
    {
        StatoPartita? statoEnum = null;
        if (!string.IsNullOrEmpty(stato) && Enum.TryParse<StatoPartita>(stato, true, out var parsed))
            statoEnum = parsed;

        var result = await _matchService.GetAllByTeamAsync(teamId, statoEnum, seasonId);
        return Ok(new ApiResponse<List<MatchDto>> { Success = true, Data = result });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<MatchDetailDto>>> GetById(int teamId, int id)
    {
        var result = await _matchService.GetByIdAsync(teamId, id);
        return Ok(new ApiResponse<MatchDetailDto> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPost]
    public async Task<ActionResult<ApiResponse<MatchDto>>> Create(int teamId, [FromBody] CreateMatchDto dto)
    {
        var result = await _matchService.CreateAsync(teamId, dto);
        return Ok(new ApiResponse<MatchDto> { Success = true, Data = result, Message = "Partita creata" });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<MatchDto>>> Update(int teamId, int id, [FromBody] UpdateMatchDto dto)
    {
        var result = await _matchService.UpdateAsync(teamId, id, dto);
        return Ok(new ApiResponse<MatchDto> { Success = true, Data = result, Message = "Partita aggiornata" });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int teamId, int id)
    {
        await _matchService.DeleteAsync(teamId, id);
        return Ok(new ApiResponse<object> { Success = true, Message = "Partita eliminata" });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPut("{id}/stato")]
    public async Task<ActionResult<ApiResponse<MatchDto>>> UpdateStato(int teamId, int id, [FromBody] StatoPartitaDto dto)
    {
        if (!Enum.TryParse<StatoPartita>(dto.Stato, true, out var stato))
            return BadRequest(new ApiResponse<object> { Success = false, Message = "Stato non valido" });

        var result = await _matchService.UpdateStatoAsync(teamId, id, stato);
        return Ok(new ApiResponse<MatchDto> { Success = true, Data = result, Message = "Stato aggiornato" });
    }
    [AllowAnonymous]
    [HttpGet("calendar.ics")]
    public async Task<IActionResult> GetCalendarIcs(int teamId)
    {
        var team = await _context.Teams.FindAsync(teamId);
        if (team == null) return NotFound();

        var matches = await _context.Matches
            .Where(m => m.TeamId == teamId)
            .OrderBy(m => m.Data)
            .ToListAsync();

        var sb = new StringBuilder();
        sb.AppendLine("BEGIN:VCALENDAR");
        sb.AppendLine("VERSION:2.0");
        sb.AppendLine($"PRODID:-//InCampo//{team.Nome}//IT");
        sb.AppendLine($"X-WR-CALNAME:{team.Nome} - Partite");
        sb.AppendLine("CALSCALE:GREGORIAN");
        sb.AppendLine("METHOD:PUBLISH");

        foreach (var match in matches)
        {
            var startDt = match.Data.Date.Add(match.Ora);
            // Durata dalla configurazione della squadra, con un margine per intervallo e spogliatoi
            var endDt = startDt.AddMinutes(team.MinutiPerTempo * team.NumeroTempi + 15);

            sb.AppendLine("BEGIN:VEVENT");
            sb.AppendLine($"UID:match-{match.Id}@calcioacinque");
            sb.AppendLine($"DTSTART:{startDt:yyyyMMdd'T'HHmmss}");
            sb.AppendLine($"DTEND:{endDt:yyyyMMdd'T'HHmmss}");
            var summary = !string.IsNullOrEmpty(match.Titolo)
                ? $"{team.Nome} - G{match.NumeroGiornata} vs {match.Titolo}"
                : $"{team.Nome} - Giornata {match.NumeroGiornata}";
            sb.AppendLine($"SUMMARY:{summary}");
            if (!string.IsNullOrEmpty(match.Luogo))
                sb.AppendLine($"LOCATION:{match.Luogo}");
            var desc = $"{TeamFormats.Label(team.Formato)} - {team.Nome}\\nGiornata {match.NumeroGiornata}\\nStato: {match.Stato}";
            if (!string.IsNullOrEmpty(match.Note))
                desc += $"\\n{match.Note}";
            sb.AppendLine($"DESCRIPTION:{desc}");
            sb.AppendLine($"STATUS:{(match.Stato == StatoPartita.Conclusa ? "CONFIRMED" : "TENTATIVE")}");
            sb.AppendLine("END:VEVENT");
        }

        sb.AppendLine("END:VCALENDAR");

        var bytes = Encoding.UTF8.GetBytes(sb.ToString());
        return File(bytes, "text/calendar", $"{team.Nome.ToLower().Replace(' ', '_')}_partite.ics");
    }
}

public class StatoPartitaDto
{
    public string Stato { get; set; } = string.Empty;
}
