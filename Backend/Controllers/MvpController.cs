using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Mvp;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class MvpController : ControllerBase
{
    private readonly IMatchVoteService _votes;

    public MvpController(IMatchVoteService votes)
    {
        _votes = votes;
    }

    private int ClaimTeamId => int.Parse(User.FindFirstValue("TeamId")!);
    private int ClaimPlayerId => int.Parse(User.FindFirstValue("PlayerId")!);

    [HttpGet("api/matches/{matchId}/mvp")]
    public async Task<ActionResult<ApiResponse<MatchMvpDto>>> Get(int matchId)
    {
        var result = await _votes.GetAsync(matchId, ClaimTeamId, ClaimPlayerId);
        return Ok(new ApiResponse<MatchMvpDto> { Success = true, Data = result });
    }

    [HttpPost("api/matches/{matchId}/mvp")]
    public async Task<ActionResult<ApiResponse<MatchMvpDto>>> Vote(int matchId, [FromBody] VoteMvpDto dto)
    {
        var result = await _votes.VoteAsync(matchId, ClaimTeamId, ClaimPlayerId, dto.PlayerId);
        return Ok(new ApiResponse<MatchMvpDto> { Success = true, Data = result, Message = "Voto registrato" });
    }

    [HttpDelete("api/matches/{matchId}/mvp")]
    public async Task<ActionResult<ApiResponse<MatchMvpDto>>> Remove(int matchId)
    {
        var result = await _votes.RemoveVoteAsync(matchId, ClaimTeamId, ClaimPlayerId);
        return Ok(new ApiResponse<MatchMvpDto> { Success = true, Data = result, Message = "Voto tolto" });
    }
}
