using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Payments;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

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
    public async Task<ActionResult<ApiResponse<List<PlayerPaymentDto>>>> GetByTeam(
        int teamId, [FromQuery] int? seasonId = null)
    {
        // Un giocatore non deve vedere i conti dei compagni: il filtro sta qui,
        // non nel client, cosi non basta una chiamata diretta all API per aggirarlo.
        // Il Mister invece NON vede la cassa, quindi vale solo per lui stesso.
        var vedeTutti = User.IsInRole(nameof(UserRole.Admin)) ||
                        User.IsInRole(nameof(UserRole.Cassiere));
        var soloDelPlayerId = vedeTutti
            ? (int?)null
            : int.Parse(User.FindFirstValue("PlayerId")!);

        var result = await _paymentService.GetByTeamAsync(teamId, soloDelPlayerId, seasonId);
        return Ok(new ApiResponse<List<PlayerPaymentDto>> { Success = true, Data = result });
    }

    [HttpGet("api/players/{playerId}/payments")]
    public async Task<ActionResult<ApiResponse<List<PlayerPaymentDto>>>> GetByPlayer(int playerId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        // Stessa regola dell'elenco di squadra: i conti di un compagno li vede
        // solo chi tiene la cassa. Senza questo bastava cambiare l'id nell'URL.
        var vedeTutti = User.IsInRole(nameof(UserRole.Admin)) ||
                        User.IsInRole(nameof(UserRole.Cassiere));
        var mioPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        if (!vedeTutti && playerId != mioPlayerId)
            return StatusCode(403, new ApiResponse<List<PlayerPaymentDto>>
            {
                Success = false,
                Message = "Puoi vedere solo i tuoi pagamenti"
            });
        var result = await _paymentService.GetByPlayerAsync(playerId, claimTeamId);
        return Ok(new ApiResponse<List<PlayerPaymentDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Soldi)]
    [HttpPost("api/players/{playerId}/payments")]
    public async Task<ActionResult<ApiResponse<PlayerPaymentDto>>> Create(
        int playerId, [FromBody] CreatePaymentDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _paymentService.CreateAsync(playerId, dto, adminPlayerId, claimTeamId);
        return Ok(new ApiResponse<PlayerPaymentDto> { Success = true, Data = result, Message = "Pagamento registrato" });
    }

    /// <summary>Crea le voci per le quote configurate sulla squadra (iscrizione/tesseramento).</summary>
    [Authorize(Roles = Ruoli.Soldi)]
    [HttpPost("api/teams/{teamId}/payments/generate")]
    public async Task<ActionResult<ApiResponse<GenerateFeesResultDto>>> GenerateFees(
        int teamId, [FromBody] GenerateFeesDto dto)
    {
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _paymentService.GenerateFeesAsync(teamId, dto, adminPlayerId);
        return Ok(new ApiResponse<GenerateFeesResultDto>
        {
            Success = true,
            Data = result,
            Message = $"{result.Create} quote create, {result.Aggiornate} aggiornate"
        });
    }

    /// <summary>Il giocatore segnala di aver pagato: la voce va in verifica, conferma l admin.</summary>
    [HttpPost("api/payments/{id}/declare")]
    public async Task<ActionResult<ApiResponse<PlayerPaymentDto>>> Declare(int id)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _paymentService.DeclareAsync(id, playerId, claimTeamId);
        return Ok(new ApiResponse<PlayerPaymentDto>
        {
            Success = true, Data = result, Message = "Segnalato: l amministratore confermera il pagamento"
        });
    }

    /// <summary>Sollecito manuale a chi ha voci non saldate.</summary>
    [Authorize(Roles = Ruoli.Soldi)]
    [HttpPost("api/teams/{teamId}/payments/remind")]
    public async Task<ActionResult<ApiResponse<RemindResultDto>>> Remind(
        int teamId, [FromBody] RemindDto dto)
    {
        var result = await _paymentService.RemindAsync(teamId, dto);
        var message = result.Sollecitati == 0
            ? "Nessun sollecito inviato"
            : $"{result.Sollecitati} solleciti inviati per {result.TotaleArretrato:0.##} EUR";
        return Ok(new ApiResponse<RemindResultDto> { Success = true, Data = result, Message = message });
    }

    [Authorize(Roles = Ruoli.Soldi)]
    [HttpPut("api/payments/{id}")]
    public async Task<ActionResult<ApiResponse<PlayerPaymentDto>>> Update(int id, [FromBody] UpdatePaymentDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _paymentService.UpdateAsync(id, dto, claimTeamId);
        return Ok(new ApiResponse<PlayerPaymentDto> { Success = true, Data = result, Message = "Pagamento aggiornato" });
    }
}
