using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Auth;
using CalcioAcinque.Backend.DTOs.Draft;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/drafts")]
[Authorize]
public class TeamDraftController : ControllerBase
{
    private readonly ITeamDraftService _draftService;

    public TeamDraftController(ITeamDraftService draftService)
    {
        _draftService = draftService;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<TeamDraftDto>>>> GetMyDrafts()
    {
        var result = await _draftService.GetMyDraftsAsync(CurrentUserId);
        return Ok(new ApiResponse<List<TeamDraftDto>> { Success = true, Data = result });
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<TeamDraftDto>>> CreateDraft([FromBody] UpsertDraftRequest request)
    {
        var result = await _draftService.CreateDraftAsync(CurrentUserId, request);
        return Ok(new ApiResponse<TeamDraftDto> { Success = true, Data = result, Message = "Draft creato" });
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ApiResponse<TeamDraftDto>>> GetDraft(int id)
    {
        var result = await _draftService.GetDraftAsync(CurrentUserId, id);
        return Ok(new ApiResponse<TeamDraftDto> { Success = true, Data = result });
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<ApiResponse<TeamDraftDto>>> UpdateDraft(int id, [FromBody] UpsertDraftRequest request)
    {
        var result = await _draftService.UpdateDraftAsync(CurrentUserId, id, request);
        return Ok(new ApiResponse<TeamDraftDto> { Success = true, Data = result, Message = "Draft aggiornato" });
    }

    [HttpDelete("{id:int}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteDraft(int id)
    {
        await _draftService.DeleteDraftAsync(CurrentUserId, id);
        return Ok(new ApiResponse<object> { Success = true, Message = "Draft cancellato" });
    }

    [HttpPost("{id:int}/candidates")]
    public async Task<ActionResult<ApiResponse<DraftCandidateDto>>> AddCandidate(int id, [FromBody] UpsertCandidateRequest request)
    {
        var result = await _draftService.AddCandidateAsync(CurrentUserId, id, request);
        return Ok(new ApiResponse<DraftCandidateDto> { Success = true, Data = result, Message = "Candidato aggiunto" });
    }

    [HttpPut("{id:int}/candidates/{candidateId:int}")]
    public async Task<ActionResult<ApiResponse<DraftCandidateDto>>> UpdateCandidate(int id, int candidateId, [FromBody] UpsertCandidateRequest request)
    {
        var result = await _draftService.UpdateCandidateAsync(CurrentUserId, id, candidateId, request);
        return Ok(new ApiResponse<DraftCandidateDto> { Success = true, Data = result, Message = "Candidato aggiornato" });
    }

    [HttpDelete("{id:int}/candidates/{candidateId:int}")]
    public async Task<ActionResult<ApiResponse<object>>> DeleteCandidate(int id, int candidateId)
    {
        await _draftService.DeleteCandidateAsync(CurrentUserId, id, candidateId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Candidato rimosso" });
    }

    [HttpPost("{id:int}/candidates/{candidateId:int}/friends")]
    public async Task<ActionResult<ApiResponse<List<DraftCandidateDto>>>> AddFriends(int id, int candidateId, [FromBody] AddFriendsRequest request)
    {
        var result = await _draftService.AddFriendsAsync(CurrentUserId, id, candidateId, request.Count);
        return Ok(new ApiResponse<List<DraftCandidateDto>> { Success = true, Data = result, Message = "Amici aggiunti" });
    }

    [HttpPost("{id:int}/launch")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> LaunchTeam(int id, [FromBody] LaunchTeamFromDraftRequest request)
    {
        var result = await _draftService.LaunchTeamAsync(CurrentUserId, id, request.NomeGiocatore, request.Soprannome);
        return Ok(new ApiResponse<LoginResponse> { Success = true, Data = result, Message = "Squadra lanciata" });
    }

    [AllowAnonymous]
    [HttpGet("share/{code}")]
    public async Task<ActionResult<ApiResponse<DraftPreviewDto>>> GetByShareCode(string code)
    {
        var preview = await _draftService.GetByShareCodeAsync(code);
        if (preview == null) return NotFound(new ApiResponse<DraftPreviewDto> { Success = false, Message = "Codice non valido" });
        return Ok(new ApiResponse<DraftPreviewDto> { Success = true, Data = preview });
    }

    [HttpPost("share/{code}/join")]
    public async Task<ActionResult<ApiResponse<TeamDraftDto>>> JoinByShareCode(string code)
    {
        var result = await _draftService.JoinByShareCodeAsync(CurrentUserId, code);
        return Ok(new ApiResponse<TeamDraftDto> { Success = true, Data = result, Message = "Sei dentro al draft" });
    }
}

public class LaunchTeamFromDraftRequest
{
    public string? NomeGiocatore { get; set; }
    public string? Soprannome { get; set; }
}
