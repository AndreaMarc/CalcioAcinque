using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [HttpGet("api/teams/{teamId}/payments")]
    public async Task<ActionResult<ApiResponse<List<PlayerPaymentDto>>>> GetByTeam(int teamId)
    {
        var result = await _paymentService.GetByTeamAsync(teamId);
        return Ok(new ApiResponse<List<PlayerPaymentDto>> { Success = true, Data = result });
    }

    [HttpGet("api/players/{playerId}/payments")]
    public async Task<ActionResult<ApiResponse<List<PlayerPaymentDto>>>> GetByPlayer(int playerId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _paymentService.GetByPlayerAsync(playerId, claimTeamId);
        return Ok(new ApiResponse<List<PlayerPaymentDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("api/players/{playerId}/payments")]
    public async Task<ActionResult<ApiResponse<PlayerPaymentDto>>> Create(
        int playerId, [FromBody] CreatePaymentDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _paymentService.CreateAsync(playerId, dto, adminPlayerId, claimTeamId);
        return Ok(new ApiResponse<PlayerPaymentDto> { Success = true, Data = result, Message = "Pagamento registrato" });
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("api/payments/{id}")]
    public async Task<ActionResult<ApiResponse<PlayerPaymentDto>>> Update(int id, [FromBody] UpdatePaymentDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _paymentService.UpdateAsync(id, dto, claimTeamId);
        return Ok(new ApiResponse<PlayerPaymentDto> { Success = true, Data = result, Message = "Pagamento aggiornato" });
    }
}
