using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Clubs;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

/// <summary>
/// Societa sportive: raggruppano piu squadre (es. una a 5 e una a 7) con anagrafica condivisa.
/// I permessi sono risolti nel servizio a partire dallo userId, non dal claim TeamId:
/// per questo nessuna route qui usa un parametro chiamato "teamId"
/// (lo intercetterebbe TeamAuthorizationMiddleware, che lo confronta col team attivo).
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ClubsController : ControllerBase
{
    private readonly IClubService _clubService;

    public ClubsController(IClubService clubService)
    {
        _clubService = clubService;
    }

    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>Catalogo dei formati disponibili con i relativi default e ruoli in campo.</summary>
    [HttpGet("formats")]
    public ActionResult<ApiResponse<List<TeamFormatDto>>> GetFormats()
    {
        return Ok(new ApiResponse<List<TeamFormatDto>> { Success = true, Data = _clubService.GetFormats() });
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<ClubDto>>>> GetMine()
    {
        var result = await _clubService.GetMyClubsAsync(UserId);
        return Ok(new ApiResponse<List<ClubDto>> { Success = true, Data = result });
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<ClubDto>>> Create([FromBody] CreateClubDto dto)
    {
        var result = await _clubService.CreateAsync(UserId, dto);
        return Ok(new ApiResponse<ClubDto> { Success = true, Data = result, Message = "Societa creata" });
    }

    [HttpGet("{clubId:int}")]
    public async Task<ActionResult<ApiResponse<ClubDto>>> GetById(int clubId)
    {
        var result = await _clubService.GetByIdAsync(UserId, clubId);
        return Ok(new ApiResponse<ClubDto> { Success = true, Data = result });
    }

    [HttpPut("{clubId:int}")]
    public async Task<ActionResult<ApiResponse<ClubDto>>> Update(int clubId, [FromBody] UpdateClubDto dto)
    {
        var result = await _clubService.UpdateAsync(UserId, clubId, dto);
        return Ok(new ApiResponse<ClubDto> { Success = true, Data = result, Message = "Societa aggiornata" });
    }

    [HttpGet("{clubId:int}/invite-code")]
    public async Task<ActionResult<ApiResponse<object>>> GetInviteCode(int clubId)
    {
        var code = await _clubService.GetInviteCodeAsync(UserId, clubId);
        return Ok(new ApiResponse<object> { Success = true, Data = new { inviteCode = code } });
    }

    [HttpPost("{clubId:int}/teams")]
    public async Task<ActionResult<ApiResponse<ClubTeamDto>>> CreateTeam(int clubId, [FromBody] CreateClubTeamDto dto)
    {
        var result = await _clubService.CreateTeamAsync(UserId, clubId, dto);
        return Ok(new ApiResponse<ClubTeamDto> { Success = true, Data = result, Message = "Squadra creata" });
    }

    // ------------------------------------------------------------- anagrafica

    [HttpGet("{clubId:int}/members")]
    public async Task<ActionResult<ApiResponse<List<ClubMemberDto>>>> GetMembers(int clubId)
    {
        var result = await _clubService.GetMembersAsync(UserId, clubId);
        return Ok(new ApiResponse<List<ClubMemberDto>> { Success = true, Data = result });
    }

    [HttpPost("{clubId:int}/members")]
    public async Task<ActionResult<ApiResponse<ClubMemberDto>>> CreateMember(int clubId, [FromBody] UpsertClubMemberDto dto)
    {
        var result = await _clubService.CreateMemberAsync(UserId, clubId, dto);
        return Ok(new ApiResponse<ClubMemberDto> { Success = true, Data = result, Message = "Anagrafica creata" });
    }

    [HttpPut("{clubId:int}/members/{memberId:int}")]
    public async Task<ActionResult<ApiResponse<ClubMemberDto>>> UpdateMember(int clubId, int memberId, [FromBody] UpsertClubMemberDto dto)
    {
        var result = await _clubService.UpdateMemberAsync(UserId, clubId, memberId, dto);
        return Ok(new ApiResponse<ClubMemberDto> { Success = true, Data = result, Message = "Anagrafica aggiornata" });
    }

    [HttpDelete("{clubId:int}/members/{memberId:int}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteMember(int clubId, int memberId)
    {
        await _clubService.DeleteMemberAsync(UserId, clubId, memberId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Anagrafica eliminata" });
    }

    /// <summary>Iscrive una persona dell'anagrafica a una squadra della societa.</summary>
    [HttpPost("{clubId:int}/members/{memberId:int}/enroll")]
    public async Task<ActionResult<ApiResponse<ClubMemberDto>>> Enroll(int clubId, int memberId, [FromBody] AssignMemberToTeamDto dto)
    {
        var result = await _clubService.AssignToTeamAsync(UserId, clubId, memberId, dto);
        return Ok(new ApiResponse<ClubMemberDto> { Success = true, Data = result, Message = "Iscritto alla squadra" });
    }

    [HttpDelete("{clubId:int}/members/{memberId:int}/enroll/{targetTeamId:int}")]
    public async Task<ActionResult<ApiResponse<ClubMemberDto>>> Unenroll(int clubId, int memberId, int targetTeamId)
    {
        var result = await _clubService.RemoveFromTeamAsync(UserId, clubId, memberId, targetTeamId);
        return Ok(new ApiResponse<ClubMemberDto> { Success = true, Data = result, Message = "Rimosso dalla squadra" });
    }
}
