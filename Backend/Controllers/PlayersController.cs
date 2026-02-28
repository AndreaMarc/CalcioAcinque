using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/teams/{teamId}/[controller]")]
[Authorize]
public class PlayersController : ControllerBase
{
    private readonly IPlayerService _playerService;

    public PlayersController(IPlayerService playerService)
    {
        _playerService = playerService;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<PlayerDto>>>> GetAll(int teamId)
    {
        var result = await _playerService.GetAllByTeamAsync(teamId);
        return Ok(new ApiResponse<List<PlayerDto>> { Success = true, Data = result });
    }

    [HttpPut("me")]
    public async Task<ActionResult<ApiResponse<PlayerDto>>> UpdateMyProfile(int teamId, [FromBody] UpdateMyProfileDto dto)
    {
        var playerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _playerService.UpdateMyProfileAsync(playerId, teamId, dto);
        return Ok(new ApiResponse<PlayerDto> { Success = true, Data = result, Message = "Profilo aggiornato" });
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ApiResponse<PlayerDetailDto>>> GetById(int teamId, int id)
    {
        var result = await _playerService.GetByIdAsync(teamId, id);
        return Ok(new ApiResponse<PlayerDetailDto> { Success = true, Data = result });
    }

    [Authorize(Roles = "Admin")]
    [HttpPost]
    public async Task<ActionResult<ApiResponse<PlayerDto>>> Create(int teamId, [FromBody] CreatePlayerDto dto)
    {
        var result = await _playerService.CreateAsync(teamId, dto);
        return Ok(new ApiResponse<PlayerDto> { Success = true, Data = result, Message = "Giocatore aggiunto" });
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{id}")]
    public async Task<ActionResult<ApiResponse<PlayerDto>>> Update(int teamId, int id, [FromBody] UpdatePlayerDto dto)
    {
        var result = await _playerService.UpdateAsync(teamId, id, dto);
        return Ok(new ApiResponse<PlayerDto> { Success = true, Data = result, Message = "Giocatore aggiornato" });
    }

    [Authorize(Roles = "Admin")]
    [HttpDelete("{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int teamId, int id)
    {
        await _playerService.DeleteAsync(teamId, id);
        return Ok(new ApiResponse<object> { Success = true, Message = "Giocatore eliminato" });
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{id}/reset-password")]
    public async Task<ActionResult<ApiResponse<object>>> ResetPassword(int teamId, int id, [FromBody] ResetPasswordDto dto)
    {
        await _playerService.ResetPasswordAsync(teamId, id, dto.NewPassword);
        return Ok(new ApiResponse<object> { Success = true, Message = "Password resettata" });
    }
}
