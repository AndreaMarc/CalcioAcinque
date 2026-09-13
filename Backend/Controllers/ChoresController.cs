using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Chores;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class ChoresController : ControllerBase
{
    private readonly IChoreService _chores;

    public ChoresController(IChoreService chores)
    {
        _chores = chores;
    }

    private int ClaimTeamId => int.Parse(User.FindFirstValue("TeamId")!);

    [HttpGet("api/teams/{teamId}/chores")]
    public async Task<ActionResult<ApiResponse<List<TeamChoreDto>>>> GetTeamChores(int teamId)
    {
        var result = await _chores.GetTeamChoresAsync(teamId);
        return Ok(new ApiResponse<List<TeamChoreDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpPost("api/teams/{teamId}/chores")]
    public async Task<ActionResult<ApiResponse<TeamChoreDto>>> Create(int teamId, [FromBody] UpsertChoreDto dto)
    {
        var result = await _chores.CreateAsync(teamId, dto);
        return Ok(new ApiResponse<TeamChoreDto> { Success = true, Data = result, Message = "Turno aggiunto" });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpPut("api/chores/{id}")]
    public async Task<ActionResult<ApiResponse<TeamChoreDto>>> Update(int id, [FromBody] UpsertChoreDto dto)
    {
        var result = await _chores.UpdateAsync(id, ClaimTeamId, dto);
        return Ok(new ApiResponse<TeamChoreDto> { Success = true, Data = result, Message = "Turno aggiornato" });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpDelete("api/chores/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int id)
    {
        await _chores.DeleteAsync(id, ClaimTeamId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Turno eliminato" });
    }

    [HttpGet("api/matches/{matchId}/chores")]
    public async Task<ActionResult<ApiResponse<List<MatchChoreDto>>>> GetMatchChores(int matchId)
    {
        var result = await _chores.GetMatchChoresAsync(matchId, ClaimTeamId);
        return Ok(new ApiResponse<List<MatchChoreDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPost("api/matches/{matchId}/chores/assign")]
    public async Task<ActionResult<ApiResponse<List<MatchChoreDto>>>> Assign(int matchId)
    {
        var result = await _chores.AssignAsync(matchId, ClaimTeamId);
        return Ok(new ApiResponse<List<MatchChoreDto>> { Success = true, Data = result, Message = "Turni assegnati" });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPut("api/matches/{matchId}/chores/{choreId}")]
    public async Task<ActionResult<ApiResponse<List<MatchChoreDto>>>> Set(int matchId, int choreId, [FromBody] SetChoreDto dto)
    {
        var result = await _chores.SetAsync(matchId, choreId, dto.PlayerId, ClaimTeamId);
        return Ok(new ApiResponse<List<MatchChoreDto>> { Success = true, Data = result, Message = "Turno aggiornato" });
    }
}
