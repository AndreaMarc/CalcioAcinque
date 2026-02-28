using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Attendance;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/matches/{matchId}/attendance")]
[Authorize]
public class AttendanceController : ControllerBase
{
    private readonly IAttendanceService _attendanceService;

    public AttendanceController(IAttendanceService attendanceService)
    {
        _attendanceService = attendanceService;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<MatchAttendanceDto>>>> GetByMatch(int matchId)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _attendanceService.GetByMatchAsync(matchId, claimTeamId);
        return Ok(new ApiResponse<List<MatchAttendanceDto>> { Success = true, Data = result });
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{playerId}")]
    public async Task<ActionResult<ApiResponse<MatchAttendanceDto>>> UpdateAttendance(
        int matchId, int playerId, [FromBody] UpdateAttendanceDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _attendanceService.UpdateAttendanceAsync(matchId, playerId, dto, adminPlayerId, claimTeamId);
        return Ok(new ApiResponse<MatchAttendanceDto> { Success = true, Data = result, Message = "Presenza aggiornata" });
    }
}
