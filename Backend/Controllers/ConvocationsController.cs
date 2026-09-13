using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Convocations;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class ConvocationsController : ControllerBase
{
    private readonly IConvocationService _convocationService;

    public ConvocationsController(IConvocationService convocationService)
    {
        _convocationService = convocationService;
    }

    [HttpGet("api/matches/{matchId}/convocations")]
    public async Task<ActionResult<ApiResponse<List<ConvocationDto>>>> GetByMatch(int matchId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _convocationService.GetByMatchAsync(matchId, claimTeamId);
        return Ok(new ApiResponse<List<ConvocationDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPost("api/matches/{matchId}/convocations")]
    public async Task<ActionResult<ApiResponse<List<ConvocationDto>>>> SendConvocations(int matchId, [FromBody] SendConvocationsDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _convocationService.SendConvocationsAsync(matchId, dto, claimTeamId);
        return Ok(new ApiResponse<List<ConvocationDto>> { Success = true, Data = result, Message = "Convocazioni inviate" });
    }

    [HttpPut("api/convocations/{id}/respond")]
    public async Task<ActionResult<ApiResponse<ConvocationDto>>> Respond(int id, [FromBody] RespondConvocationDto dto)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _convocationService.RespondAsync(id, playerId, dto);
        return Ok(new ApiResponse<ConvocationDto> { Success = true, Data = result, Message = "Risposta registrata" });
    }

    /// <summary>Toglie una convocazione: libera il posto per un sostituto.</summary>
    [Authorize(Roles = Ruoli.Campo)]
    [HttpDelete("api/convocations/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Revoke(int id)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        await _convocationService.RevokeAsync(id, claimTeamId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Convocazione rimossa" });
    }

    [HttpGet("api/players/{playerId}/convocations/pending")]
    public async Task<ActionResult<ApiResponse<List<ConvocationDto>>>> GetPending(int playerId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _convocationService.GetPendingByPlayerAsync(playerId, claimTeamId);
        return Ok(new ApiResponse<List<ConvocationDto>> { Success = true, Data = result });
    }
}
