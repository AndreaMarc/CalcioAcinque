using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Availability;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class AvailabilityController : ControllerBase
{
    private readonly IAvailabilityService _availabilityService;

    public AvailabilityController(IAvailabilityService availabilityService)
    {
        _availabilityService = availabilityService;
    }

    /// <summary>
    /// Dichiara la propria disponibilita' per una partita
    /// </summary>
    [HttpPost("api/matches/{matchId}/availability")]
    public async Task<ActionResult<ApiResponse<AvailabilityDto>>> SetAvailability(
        int matchId, [FromBody] SetAvailabilityDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _availabilityService.SetAvailabilityAsync(matchId, playerId, dto, claimTeamId);
        return Ok(new ApiResponse<AvailabilityDto>
        {
            Success = true, Data = result,
            Message = dto.Disponibile ? "Sei disponibile!" : "Non disponibile registrato"
        });
    }

    /// <summary>
    /// Ottieni tutte le disponibilita' per una partita
    /// </summary>
    [HttpGet("api/matches/{matchId}/availability")]
    public async Task<ActionResult<ApiResponse<MatchAvailabilitySummaryDto>>> GetByMatch(int matchId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _availabilityService.GetByMatchAsync(matchId, playerId, claimTeamId);
        return Ok(new ApiResponse<MatchAvailabilitySummaryDto> { Success = true, Data = result });
    }

    /// <summary>
    /// Ottieni la disponibilita' per la prossima partita del team
    /// </summary>
    [HttpGet("api/teams/{teamId}/next-availability")]
    public async Task<ActionResult<ApiResponse<MatchAvailabilitySummaryDto?>>> GetNextMatch(int teamId)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _availabilityService.GetNextMatchAvailabilityAsync(teamId, playerId);
        return Ok(new ApiResponse<MatchAvailabilitySummaryDto?> { Success = true, Data = result });
    }
}
