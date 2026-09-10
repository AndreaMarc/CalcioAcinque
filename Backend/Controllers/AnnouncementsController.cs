using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Announcements;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/teams/{teamId}/[controller]")]
[Authorize]
public class AnnouncementsController : ControllerBase
{
    private readonly IAnnouncementService _announcementService;

    public AnnouncementsController(IAnnouncementService announcementService)
    {
        _announcementService = announcementService;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<AnnouncementDto>>>> GetAll(int teamId)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _announcementService.GetAllByTeamAsync(teamId, playerId);
        return Ok(new ApiResponse<List<AnnouncementDto>> { Success = true, Data = result });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<AnnouncementDetailDto>>> GetById(int teamId, int id)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _announcementService.GetByIdAsync(teamId, id, playerId);
        return Ok(new ApiResponse<AnnouncementDetailDto> { Success = true, Data = result });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpPost]
    public async Task<ActionResult<ApiResponse<AnnouncementDto>>> Create(int teamId, [FromBody] CreateAnnouncementDto dto)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _announcementService.CreateAsync(teamId, playerId, dto);
        return Ok(new ApiResponse<AnnouncementDto> { Success = true, Data = result, Message = "Comunicazione pubblicata" });
    }

    [Authorize(Roles = Ruoli.Campo)]
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int teamId, int id)
    {
        await _announcementService.DeleteAsync(teamId, id);
        return Ok(new ApiResponse<object> { Success = true, Message = "Comunicazione eliminata" });
    }

    [HttpPost("{id}/acknowledge")]
    public async Task<ActionResult<ApiResponse<object>>> Acknowledge(int teamId, int id)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        await _announcementService.AcknowledgeAsync(teamId, id, playerId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Presa visione registrata" });
    }
}
