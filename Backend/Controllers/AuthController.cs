using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;
using CalcioAcinque.Backend.Models.Enums;

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

    [EnableRateLimiting("auth")]
    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Login effettuato" });
    }

    [EnableRateLimiting("auth")]
    [HttpPost("signup")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Signup([FromBody] SignupRequest request)
    {
        var result = await _authService.SignupAsync(request);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Registrazione completata" });
    }

    [Authorize(Roles = Ruoli.Squadra)]
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
    public async Task<ActionResult<ApiResponse<MeResponse>>> Me([FromQuery] int? teamId = null)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _authService.GetMeAsync(userId, teamId);
        if (result == null) return NotFound(new ApiResponse<MeResponse> { Success = false, Message = "Utente non trovato" });
        return Ok(new ApiResponse<MeResponse> { Success = true, Data = result });
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

    [Authorize]
    [HttpGet("join-info/{code}")]
    public async Task<ActionResult<ApiResponse<JoinInfoResponse>>> GetJoinInfo(string code)
    {
        var result = await _authService.GetJoinInfoAsync(code);
        if (result == null)
            return NotFound(new ApiResponse<JoinInfoResponse> { Success = false, Message = "Codice invito non valido" });
        return Ok(new ApiResponse<JoinInfoResponse> { Success = true, Data = result });
    }

    /// <summary>Cambio password dell'utente autenticato (richiede quella attuale).</summary>
    [Authorize]
    [HttpPost("change-password")]
    public async Task<ActionResult<ApiResponse<object>>> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _authService.ChangePasswordAsync(userId, request);
        return Ok(new ApiResponse<object> { Success = true, Message = "Password aggiornata" });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpGet("invite-code")]
    public async Task<ActionResult<ApiResponse<object>>> GetInviteCode()
    {
        var teamId = int.Parse(User.FindFirstValue("TeamId")!);
        var team = await _authService.GetTeamInviteCodeAsync(teamId);
        return Ok(new ApiResponse<object> { Success = true, Data = new { inviteCode = team } });
    }
}
