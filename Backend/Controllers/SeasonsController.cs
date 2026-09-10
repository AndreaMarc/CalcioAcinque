using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using CalcioAcinque.Backend.DTOs.Seasons;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/teams/{teamId}/seasons")]
[Authorize]
public class SeasonsController : ControllerBase
{
    private readonly ISeasonService _seasons;

    public SeasonsController(ISeasonService seasons)
    {
        _seasons = seasons;
    }

    /// <summary>Elenco delle stagioni, con partite e conti di ciascuna.</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<SeasonDto>>>> GetAll(int teamId)
    {
        var result = await _seasons.GetByTeamAsync(teamId);
        return Ok(new ApiResponse<List<SeasonDto>> { Success = true, Data = result });
    }

    /// <summary>
    /// Chiude la stagione corrente e ne apre una nuova. E' un'azione che azzera
    /// gettoni e quote di tutti, quindi resta all'admin e non al mister.
    /// </summary>
    [Authorize(Roles = Ruoli.Squadra)]
    [HttpPost("close")]
    public async Task<ActionResult<ApiResponse<CloseSeasonResultDto>>> Close(
        int teamId, [FromBody] CloseSeasonDto dto)
    {
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _seasons.CloseAsync(teamId, dto, adminPlayerId);
        return Ok(new ApiResponse<CloseSeasonResultDto>
        {
            Success = true,
            Data = result,
            Message = $"Stagione {result.StagioneChiusa} chiusa, aperta {result.StagioneNuova}"
        });
    }
}
