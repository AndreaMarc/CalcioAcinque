using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Players;
using CalcioAcinque.Backend.Models;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Controllers;

[ApiController]
[Route("api/teams/{teamId}/pending-players")]
[Authorize]
public class PendingPlayersController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PendingPlayersController(ApplicationDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<PendingPlayerDto>>>> GetAll(int teamId)
    {
        var pending = await _context.PendingPlayers
            .Where(p => p.TeamId == teamId && !p.Claimed)
            .OrderBy(p => p.Nome)
            .ToListAsync();

        var dtos = pending.Select(p => new PendingPlayerDto
        {
            Id = p.Id,
            Nome = p.Nome,
            Soprannome = p.Soprannome,
            Posizione = p.Posizione?.ToString(),
            Bravura = p.Bravura,
            Affidabilita = p.Affidabilita,
            Tesserato = p.Tesserato,
            Note = p.Note
        }).ToList();

        return Ok(new ApiResponse<List<PendingPlayerDto>> { Success = true, Data = dtos });
    }

    [Authorize(Roles = Ruoli.Squadra)]
    [HttpDelete("{id:int}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(int teamId, int id)
    {
        var pending = await _context.PendingPlayers
            .FirstOrDefaultAsync(p => p.Id == id && p.TeamId == teamId);
        if (pending == null)
            return NotFound(new ApiResponse<object> { Success = false, Message = "Giocatore in attesa non trovato" });

        _context.PendingPlayers.Remove(pending);
        await _context.SaveChangesAsync();
        return Ok(new ApiResponse<object> { Success = true, Message = "Rimosso" });
    }
}
