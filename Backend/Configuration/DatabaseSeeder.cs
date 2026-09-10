using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;

namespace CalcioAcinque.Backend.Configuration;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        if (context.Teams.Any()) return;

        // Societa demo con due squadre di formato diverso e l'admin iscritto a entrambe:
        // e' lo scenario reale (giocatori condivisi, regole e costi separati).
        var club = new Club
        {
            Nome = "ASD Campioni del Giovedi",
            InviteCode = "DEMOCLUB",
            CreatedAt = DateTime.UtcNow
        };
        context.Clubs.Add(club);
        await context.SaveChangesAsync();

        var teamA5 = new Team
        {
            ClubId = club.Id,
            Nome = "Campioni A5",
            Formato = TeamFormat.CalcioA5,
            PartitePerStagione = 8,
            GettoniPerGiocatore = 4,
            QuotaIscrizione = 60m,
            QuotaTesseramento = 15m,
            CostoPartita = 8m,
            CreatedAt = DateTime.UtcNow
        };
        teamA5.ApplyFormatDefaults();

        var teamA7 = new Team
        {
            ClubId = club.Id,
            Nome = "Campioni A7",
            Formato = TeamFormat.CalcioA7,
            PartitePerStagione = 14,
            GettoniPerGiocatore = 7,
            QuotaIscrizione = 90m,
            QuotaTesseramento = 25m,
            CostoPartita = 10m,
            CreatedAt = DateTime.UtcNow
        };
        teamA7.ApplyFormatDefaults();

        context.Teams.AddRange(teamA5, teamA7);
        await context.SaveChangesAsync();

        var adminUser = new User
        {
            Email = "admin@incampo.it",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123"),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        context.Users.Add(adminUser);
        await context.SaveChangesAsync();

        var adminMember = new ClubMember
        {
            ClubId = club.Id,
            UserId = adminUser.Id,
            Nome = "Admin",
            Soprannome = "Boss",
            CreatedAt = DateTime.UtcNow
        };
        context.ClubMembers.Add(adminMember);
        await context.SaveChangesAsync();

        foreach (var (team, posizione) in new[]
                 {
                     (teamA5, PlayerPosition.Pivot),
                     (teamA7, PlayerPosition.Centrocampista)
                 })
        {
            context.Players.Add(new Player
            {
                TeamId = team.Id,
                UserId = adminUser.Id,
                ClubMemberId = adminMember.Id,
                Nome = adminMember.Nome,
                Soprannome = adminMember.Soprannome,
                Ruolo = UserRole.Admin,
                Posizione = posizione,
                GettoniTotali = team.GettoniPerGiocatore,
                GettoniConsumati = 0,
                CreatedAt = DateTime.UtcNow
            });
        }

        await context.SaveChangesAsync();
    }
}
