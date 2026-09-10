using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Tokens;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class TokensController : ControllerBase
{
    private readonly ITokenService _tokenService;

    public TokensController(ITokenService tokenService)
    {
        _tokenService = tokenService;
    }

    [HttpGet("api/teams/{teamId}/tokens")]
    public async Task<ActionResult<ApiResponse<List<PlayerTokenSummaryDto>>>> GetTeamSummary(int teamId)
    {
        var result = await _tokenService.GetTeamTokenSummaryAsync(teamId);
        return Ok(new ApiResponse<List<PlayerTokenSummaryDto>> { Success = true, Data = result });
    }

    [HttpGet("api/players/{playerId}/tokens")]
    public async Task<ActionResult<ApiResponse<List<TokenTransactionDto>>>> GetPlayerTransactions(int playerId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _tokenService.GetPlayerTransactionsAsync(playerId, claimTeamId);
        return Ok(new ApiResponse<List<TokenTransactionDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Gettoni)]
    [HttpPost("api/players/{playerId}/tokens")]
    public async Task<ActionResult<ApiResponse<TokenTransactionDto>>> ManualAdjust(
        int playerId, [FromBody] ManualTokenDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _tokenService.ManualAdjustAsync(playerId, dto, adminPlayerId, claimTeamId);
        return Ok(new ApiResponse<TokenTransactionDto> { Success = true, Data = result, Message = "Gettoni aggiornati" });
    }
}
