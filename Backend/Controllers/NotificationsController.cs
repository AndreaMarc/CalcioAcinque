using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Notifications;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

/// <summary>
/// Notifiche push. Sono per utente e non per squadra, quindi nessuna route ha un
/// parametro "teamId": lo intercetterebbe TeamAuthorizationMiddleware, e le
/// impostazioni devono restare raggiungibili anche prima di scegliere una squadra.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notifications;

    public NotificationsController(INotificationService notifications)
    {
        _notifications = notifications;
    }

    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>Chiave pubblica VAPID e stato delle preferenze dell'utente.</summary>
    [HttpGet("config")]
    public async Task<ActionResult<ApiResponse<PushConfigDto>>> GetConfig()
    {
        var result = await _notifications.GetConfigAsync(UserId);
        return Ok(new ApiResponse<PushConfigDto> { Success = true, Data = result });
    }

    [HttpPost("subscriptions")]
    public async Task<ActionResult<ApiResponse<object>>> Subscribe([FromBody] RegisterPushDeviceDto dto)
    {
        await _notifications.RegisterDeviceAsync(UserId, dto);
        return Ok(new ApiResponse<object> { Success = true, Message = "Notifiche attivate su questo dispositivo" });
    }

    [HttpPost("subscriptions/remove")]
    public async Task<ActionResult<ApiResponse<object>>> Unsubscribe([FromBody] UnregisterPushDeviceDto dto)
    {
        await _notifications.UnregisterDeviceAsync(UserId, dto.Endpoint);
        return Ok(new ApiResponse<object> { Success = true, Message = "Notifiche disattivate su questo dispositivo" });
    }

    [HttpPut("preferences")]
    public async Task<ActionResult<ApiResponse<PushConfigDto>>> UpdatePreference(
        [FromBody] UpdateNotificationPreferenceDto dto)
    {
        await _notifications.UpdatePreferenceAsync(UserId, dto);
        var result = await _notifications.GetConfigAsync(UserId);
        return Ok(new ApiResponse<PushConfigDto> { Success = true, Data = result });
    }

    [HttpPost("test")]
    public async Task<ActionResult<ApiResponse<object>>> SendTest()
    {
        var dispositivi = await _notifications.SendTestAsync(UserId);
        return Ok(new ApiResponse<object>
        {
            Success = true,
            Message = $"Notifica di prova in arrivo su {dispositivi} dispositiv{(dispositivi == 1 ? "o" : "i")}"
        });
    }
}
