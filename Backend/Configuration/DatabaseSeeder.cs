using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Configuration;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        if (context.Teams.Any()) return;

        var team = new Team
        {
            Nome = "I Campioni del Giovedi",
            PartitePerStagione = 8,
            GettoniPerGiocatore = 4,
            CreatedAt = DateTime.UtcNow
        };
        context.Teams.Add(team);
        await context.SaveChangesAsync();

        var adminUser = new User
        {
            Email = "admin@calcioacinque.it",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Users.Add(adminUser);
        await context.SaveChangesAsync();

        var adminPlayer = new Player
        {
            TeamId = team.Id,
            UserId = adminUser.Id,
            Nome = "Admin",
            Soprannome = "Boss",
            Ruolo = UserRole.Admin,
            GettoniTotali = team.GettoniPerGiocatore,
            GettoniConsumati = 0,
            CreatedAt = DateTime.UtcNow
        };
        context.Players.Add(adminPlayer);
        await context.SaveChangesAsync();
    }
}
