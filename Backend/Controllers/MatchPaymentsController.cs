using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

/// <summary>
/// Incasso di una partita. Il teamId arriva dal claim e non dalla route, come in
/// AttendanceController: le route /api/matches/{matchId}/... non passano da
/// TeamAuthorizationMiddleware, quindi la verifica sta nel servizio.
/// </summary>
[ApiController]
[Authorize(Roles = Ruoli.Soldi)]
public class MatchPaymentsController : ControllerBase
{
    private readonly IMatchPaymentService _matchPayments;

    public MatchPaymentsController(IMatchPaymentService matchPayments)
    {
        _matchPayments = matchPayments;
    }

    private int TeamId => int.Parse(User.FindFirstValue("TeamId")!);
    private int PlayerId => int.Parse(User.FindFirstValue("PlayerId")!);

    /// <summary>Chi propone di addebitare, con motivo per chi resta fuori.</summary>
    [HttpGet("api/matches/{matchId}/payments/preview")]
    public async Task<ActionResult<ApiResponse<MatchPaymentPreviewDto>>> Preview(int matchId)
    {
        var result = await _matchPayments.PreviewAsync(matchId, TeamId);
        return Ok(new ApiResponse<MatchPaymentPreviewDto> { Success = true, Data = result });
    }

    [HttpPost("api/matches/{matchId}/payments")]
    public async Task<ActionResult<ApiResponse<ConfirmMatchPaymentResultDto>>> Confirm(
        int matchId, [FromBody] ConfirmMatchPaymentDto dto)
    {
        var result = await _matchPayments.ConfirmAsync(matchId, dto, PlayerId, TeamId);

        var message = result.Addebitati == 0
            ? "Nessun addebito creato"
            : $"{result.Addebitati} addebiti per {result.TotaleAddebitato:0.##} EUR" +
              (result.NotificheAccodate > 0 ? $", {result.NotificheAccodate} notifiche inviate" : string.Empty);

        return Ok(new ApiResponse<ConfirmMatchPaymentResultDto>
        {
            Success = true,
            Data = result,
            Message = message
        });
    }
}
