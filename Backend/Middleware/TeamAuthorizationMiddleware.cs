using System.Security.Claims;
using CalcioAcinque.Backend.Models;

namespace CalcioAcinque.Backend.Middleware;

public class TeamAuthorizationMiddleware
{
    private readonly RequestDelegate _next;

    public TeamAuthorizationMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Solo per route con {teamId} e utenti autenticati
        if (context.User.Identity?.IsAuthenticated == true &&
            context.Request.RouteValues.TryGetValue("teamId", out var teamIdValue))
        {
            if (int.TryParse(teamIdValue?.ToString(), out var routeTeamId))
            {
                var claimTeamId = context.User.FindFirstValue("TeamId");

                if (claimTeamId == null)
                {
                    // Token di sessione senza contesto team
                    context.Response.StatusCode = 403;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "Seleziona un team prima di continuare"
                    });
                    return;
                }

                if (int.Parse(claimTeamId) != routeTeamId)
                {
                    context.Response.StatusCode = 403;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new ApiResponse<object>
                    {
                        Success = false,
                        Message = "Non sei autorizzato ad accedere a questo team"
                    });
                    return;
                }
            }
        }

        await _next(context);
    }
}
