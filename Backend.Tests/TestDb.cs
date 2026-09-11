using CalcioAcinque.Backend.Configuration;
using CalcioAcinque.Backend.DTOs.Notifications;
using CalcioAcinque.Backend.Models.Entities;
using CalcioAcinque.Backend.Models.Enums;
using CalcioAcinque.Backend.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;

namespace CalcioAcinque.Backend.Tests;

/// <summary>
/// Un database in memoria per test, con una squadra gia' pronta.
/// I servizi che maneggiano soldi e gettoni sono quelli da proteggere:
/// qui si costruiscono con dipendenze finte, senza MySQL.
/// </summary>
public sealed class TestDb : IDisposable
{
    public ApplicationDbContext Db { get; }
    public Team Team { get; private set; } = null!;
    public Player Admin { get; private set; } = null!;
    public Player Giocatore { get; private set; } = null!;
    public FakeNotifications Notifiche { get; } = new();

    public TestDb()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase("incampo-test-" + Guid.NewGuid())
            // Il provider in memoria non ha transazioni: i servizi le usano, qui si ignorano
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;
        Db = new ApplicationDbContext(options);
        Seed();
    }

    private void Seed()
    {
        var club = new Club { Nome = "ASD Test", InviteCode = "CLUBTEST", CreatedByUserId = 1 };
        Db.Clubs.Add(club);
        Db.SaveChanges();

        Team = new Team
        {
            ClubId = club.Id,
            Nome = "Test C5",
            Formato = TeamFormat.CalcioA5,
            UseGettoni = true,
            GettoniPerGiocatore = 4,
            QuotaIscrizione = 100m,
            QuotaTesseramento = 20m,
            RegimePagamentoDefault = RegimePagamento.Stagionale,
            InviteCode = "TEAMTEST",
        };
        Team.ApplyFormatDefaults();
        Db.Teams.Add(Team);
        Db.SaveChanges();

        Admin = AddPlayer("Admin", UserRole.Admin);
        Giocatore = AddPlayer("Gigi", UserRole.User);
    }

    public Player AddPlayer(string nome, UserRole ruolo = UserRole.User, RegimePagamento? regime = null, int? gettoni = null)
    {
        var user = new User { Email = $"{nome.ToLower()}@test.it", PasswordHash = "x" };
        Db.Users.Add(user);
        Db.SaveChanges();
        var player = new Player
        {
            TeamId = Team.Id,
            UserId = user.Id,
            Nome = nome,
            Ruolo = ruolo,
            RegimePagamento = regime,
            GettoniTotali = gettoni ?? Team.GettoniPerGiocatore,
            GettoniConsumati = 0,
        };
        Db.Players.Add(player);
        Db.SaveChanges();
        return player;
    }

    public Match AddMatch(StatoPartita stato = StatoPartita.InCorso, int? seasonId = null)
    {
        var match = new Match
        {
            TeamId = Team.Id,
            SeasonId = seasonId,
            Data = DateTime.UtcNow.Date,
            Ora = new TimeSpan(21, 0, 0),
            NumeroGiornata = Db.Matches.Count(m => m.TeamId == Team.Id) + 1,
            Stato = stato,
        };
        Db.Matches.Add(match);
        Db.SaveChanges();
        return match;
    }

    public MatchAttendance AddAttendance(Match match, Player player)
    {
        var att = new MatchAttendance { MatchId = match.Id, PlayerId = player.Id, Convocato = true };
        Db.MatchAttendances.Add(att);
        Db.SaveChanges();
        return att;
    }

    public SeasonService Seasons() => new(Db, NullLogger<SeasonService>.Instance);
    public AttendanceService Attendance() => new(Db, NullLogger<AttendanceService>.Instance);
    public PaymentService Payments() => new(Db, Notifiche, Seasons());
    public MatchService Matches() => new(Db, Notifiche, Seasons());
    public PlayerService Players() => new(Db);

    public void Dispose() => Db.Dispose();
}

/// <summary>Notifiche finte: registra le chiamate, non spedisce nulla.</summary>
public sealed class FakeNotifications : INotificationService
{
    public List<(NotificationKind kind, int destinatari, string titolo)> Accodate { get; } = new();

    public Task<PushConfigDto> GetConfigAsync(int userId) => Task.FromResult(new PushConfigDto());
    public Task RegisterDeviceAsync(int userId, RegisterPushDeviceDto dto) => Task.CompletedTask;
    public Task UnregisterDeviceAsync(int userId, string endpoint) => Task.CompletedTask;
    public Task UpdatePreferenceAsync(int userId, UpdateNotificationPreferenceDto dto) => Task.CompletedTask;
    public Task<int> SendTestAsync(int userId) => Task.FromResult(0);

    public Task<int> QueueAsync(NotificationKind kind, IEnumerable<int> recipientUserIds, string titolo, string corpo,
        string? url = null, string? tag = null, int? teamId = null, DateTime? scheduledFor = null, CancellationToken ct = default)
    {
        var n = recipientUserIds.Count();
        Accodate.Add((kind, n, titolo));
        return Task.FromResult(n);
    }
}
