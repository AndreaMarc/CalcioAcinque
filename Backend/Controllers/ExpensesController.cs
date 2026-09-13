using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using CalcioAcinque.Backend.DTOs.Cassa;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;

namespace CalcioAcinque.Backend.Controllers;

/// <summary>Uscite di cassa e cruscotto: solo chi tiene la cassa.</summary>
[ApiController]
[Authorize(Roles = Ruoli.Soldi)]
public class ExpensesController : ControllerBase
{
    private readonly IExpenseService _expenses;

    public ExpensesController(IExpenseService expenses)
    {
        _expenses = expenses;
    }

    [HttpGet("api/teams/{teamId}/expenses")]
    public async Task<ActionResult<ApiResponse<List<TeamExpenseDto>>>> GetByTeam(int teamId, [FromQuery] int? seasonId = null)
    {
        var result = await _expenses.GetByTeamAsync(teamId, seasonId);
        return Ok(new ApiResponse<List<TeamExpenseDto>> { Success = true, Data = result });
    }

    [HttpPost("api/teams/{teamId}/expenses")]
    public async Task<ActionResult<ApiResponse<TeamExpenseDto>>> Create(int teamId, [FromBody] UpsertExpenseDto dto)
    {
        var adminPlayerId = int.Parse(User.FindFirstValue("PlayerId")!);
        var result = await _expenses.CreateAsync(teamId, dto, adminPlayerId);
        return Ok(new ApiResponse<TeamExpenseDto> { Success = true, Data = result, Message = "Uscita registrata" });
    }

    [HttpPut("api/expenses/{id}")]
    public async Task<ActionResult<ApiResponse<TeamExpenseDto>>> Update(int id, [FromBody] UpsertExpenseDto dto)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        var result = await _expenses.UpdateAsync(id, claimTeamId, dto);
        return Ok(new ApiResponse<TeamExpenseDto> { Success = true, Data = result, Message = "Uscita aggiornata" });
    }

    [HttpDelete("api/expenses/{id}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int id)
    {
        var claimTeamId = int.Parse(User.FindFirstValue("TeamId")!);
        await _expenses.DeleteAsync(id, claimTeamId);
        return Ok(new ApiResponse<object> { Success = true, Message = "Uscita eliminata" });
    }

    [HttpGet("api/teams/{teamId}/cassa")]
    public async Task<ActionResult<ApiResponse<CassaSummaryDto>>> GetCassa(int teamId, [FromQuery] int? seasonId = null)
    {
        var result = await _expenses.GetCassaAsync(teamId, seasonId);
        return Ok(new ApiResponse<CassaSummaryDto> { Success = true, Data = result });
    }
}
