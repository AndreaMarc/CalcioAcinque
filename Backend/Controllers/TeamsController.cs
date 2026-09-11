using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Teams;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TeamsController : ControllerBase
{
    private readonly ITeamService _teamService;

    public TeamsController(ITeamService teamService)
    {
        _teamService = teamService;
    }

    [HttpGet("{teamId}")]
    public async Task<ActionResult<ApiResponse<TeamDto>>> GetById(int teamId)
    {
        var result = await _teamService.GetByIdAsync(teamId);
        return Ok(new ApiResponse<TeamDto> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpPut("{teamId}")]
    public async Task<ActionResult<ApiResponse<TeamDto>>> Update(int teamId, [FromBody] UpdateTeamDto dto)
    {
        var result = await _teamService.UpdateAsync(teamId, dto);
        return Ok(new ApiResponse<TeamDto> { Success = true, Data = result, Message = "Team aggiornato" });
    }
}
