using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Login effettuato" });
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("register")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Register([FromBody] RegisterRequest request)
    {
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _authService.RegisterAsync(request, adminPlayerId);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Registrazione completata" });
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Refresh([FromBody] RefreshTokenRequest request)
    {
        var result = await _authService.RefreshTokenAsync(request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Token aggiornato" });
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<PlayerInfo>>> Me([FromQuery] int? teamId = null)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.GetCurrentPlayerAsync(userId, teamId);
        if (result == null) return NotFound(new ApiResponse<PlayerInfo> { Success = false, Message = "Utente non trovato" });
        return Ok(new ApiResponse<PlayerInfo> { Success = true, Data = result });
    }

    [Authorize]
    [HttpPost("select-team")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> SelectTeam([FromBody] SelectTeamRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.SelectTeamAsync(userId, request.TeamId);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Team selezionato" });
    }

    [Authorize]
    [HttpGet("teams")]
    public async Task<ActionResult<ApiResponse<List<TeamMembershipInfo>>>> GetMyTeams()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.GetUserTeamsAsync(userId);
        return Ok(new ApiResponse<List<TeamMembershipInfo>> { Success = true, Data = result });
    }

    [Authorize]
    [HttpPost("create-team")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> CreateTeam([FromBody] CreateTeamRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.CreateTeamAsync(userId, request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Team creato" });
    }

    [Authorize]
    [HttpPost("join-team")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> JoinTeam([FromBody] JoinTeamRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.JoinTeamAsync(userId, request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Ti sei unito al team" });
    }

    [Authorize(Roles = "Admin")]
    [HttpGet("invite-code")]
    public async Task<ActionResult<ApiResponse<object>>> GetInviteCode()
    {
        var teamId = int.Parse(User.FindFirstValue("TeamId")!);
        var team = await _authService.GetTeamInviteCodeAsync(teamId);
        return Ok(new ApiResponse<object> { Success = true, Data = new { inviteCode = team } });
    }
}
