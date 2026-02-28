using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Stats;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public class StatsController : ControllerBase
{
    private readonly IStatsService _statsService;

    public StatsController(IStatsService statsService)
    {
        _statsService = statsService;
    }

    [HttpGet("teams/{teamId}/stats")]
    public async Task<ActionResult<ApiResponse<TeamStatsDto>>> GetTeamStats(int teamId)
    {
        var result = await _statsService.GetTeamStatsAsync(teamId);
        return Ok(new ApiResponse<TeamStatsDto> { Success = true, Data = result });
    }

    [HttpGet("players/{playerId}/stats")]
    public async Task<ActionResult<ApiResponse<PlayerStatsDto>>> GetPlayerStats(int playerId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _statsService.GetPlayerStatsAsync(playerId, claimTeamId);
        return Ok(new ApiResponse<PlayerStatsDto> { Success = true, Data = result });
    }
}
