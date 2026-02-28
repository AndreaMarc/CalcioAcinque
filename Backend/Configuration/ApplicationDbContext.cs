using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Models.Entities;

namespace CalcioAcinque.Backend.Configuration;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Team> Teams { get; set; } = null!;
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<Player> Players { get; set; } = null!;
    public DbSet<PlayerPayment> PlayerPayments { get; set; } = null!;
    public DbSet<Match> Matches { get; set; } = null!;
    public DbSet<Convocation> Convocations { get; set; } = null!;
    public DbSet<MatchAttendance> MatchAttendances { get; set; } = null!;
    public DbSet<TokenTransaction> TokenTransactions { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<PlayerAvailability> PlayerAvailabilities { get; set; } = null!;
    public DbSet<Announcement> Announcements { get; set; } = null!;
    public DbSet<AnnouncementRead> AnnouncementReads { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configurazione User
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.Property(e => e.Email).HasMaxLength(255).IsRequired();
        });

        // Configurazione Team
        modelBuilder.Entity<Team>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();
        });

        // Configurazione Player
        modelBuilder.Entity<Player>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.UserId }).IsUnique();

            entity.Property(e => e.Ruolo).HasConversion<string>();

            entity.HasOne(e => e.Team)
                .WithMany(t => t.Players)
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.User)
                .WithMany(u => u.Players)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione PlayerPayment
        modelBuilder.Entity<PlayerPayment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.PlayerId);

            entity.HasOne(e => e.Player)
                .WithMany(p => p.Payments)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Admin)
                .WithMany()
                .HasForeignKey(e => e.AdminId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configurazione Match
        modelBuilder.Entity<Match>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.NumeroGiornata });
            entity.HasIndex(e => new { e.TeamId, e.Data });

            entity.Property(e => e.Stato).HasConversion<string>();

            entity.HasOne(e => e.Team)
                .WithMany(t => t.Matches)
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione Convocation
        modelBuilder.Entity<Convocation>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MatchId, e.PlayerId }).IsUnique();

            entity.Property(e => e.StatoRisposta).HasConversion<string>();

            entity.HasOne(e => e.Match)
                .WithMany(m => m.Convocations)
                .HasForeignKey(e => e.MatchId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Player)
                .WithMany(p => p.Convocations)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione MatchAttendance
        modelBuilder.Entity<MatchAttendance>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MatchId, e.PlayerId }).IsUnique();

            entity.HasOne(e => e.Match)
                .WithMany(m => m.Attendances)
                .HasForeignKey(e => e.MatchId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Player)
                .WithMany(p => p.Attendances)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione TokenTransaction
        modelBuilder.Entity<TokenTransaction>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.PlayerId, e.Timestamp });
            entity.HasIndex(e => e.MatchId);

            entity.Property(e => e.Tipo).HasConversion<string>();

            entity.HasOne(e => e.Player)
                .WithMany(p => p.TokenTransactions)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Match)
                .WithMany(m => m.TokenTransactions)
                .HasForeignKey(e => e.MatchId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(e => e.Admin)
                .WithMany()
                .HasForeignKey(e => e.AdminId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configurazione RefreshToken
        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Token).IsUnique();
            entity.HasIndex(e => e.UserId);

            entity.HasOne(e => e.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione PlayerAvailability
        modelBuilder.Entity<PlayerAvailability>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MatchId, e.PlayerId }).IsUnique();

            entity.HasOne(e => e.Match)
                .WithMany(m => m.Availabilities)
                .HasForeignKey(e => e.MatchId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Player)
                .WithMany(p => p.Availabilities)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione Announcement
        modelBuilder.Entity<Announcement>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.CreatedAt });

            entity.HasOne(e => e.Team)
                .WithMany()
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Author)
                .WithMany()
                .HasForeignKey(e => e.AuthorId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // Configurazione AnnouncementRead
        modelBuilder.Entity<AnnouncementRead>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.AnnouncementId, e.PlayerId }).IsUnique();

            entity.HasOne(e => e.Announcement)
                .WithMany(a => a.Reads)
                .HasForeignKey(e => e.AnnouncementId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Player)
                .WithMany()
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
