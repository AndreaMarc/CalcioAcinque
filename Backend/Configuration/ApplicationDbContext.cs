using Microsoft.EntityFrameworkCore;
using CalcioAcinque.Backend.Models.Entities;

namespace CalcioAcinque.Backend.Configuration;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Club> Clubs { get; set; } = null!;
    public DbSet<ClubMember> ClubMembers { get; set; } = null!;
    public DbSet<Team> Teams { get; set; } = null!;
    public DbSet<Season> Seasons { get; set; } = null!;
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
    public DbSet<TeamDraft> TeamDrafts { get; set; } = null!;
    public DbSet<DraftCandidate> DraftCandidates { get; set; } = null!;
    public DbSet<DraftCollaborator> DraftCollaborators { get; set; } = null!;
    public DbSet<PendingPlayer> PendingPlayers { get; set; } = null!;
    public DbSet<PushDevice> PushDevices { get; set; } = null!;
    public DbSet<NotificationPreference> NotificationPreferences { get; set; } = null!;
    public DbSet<NotificationOutboxItem> NotificationOutbox { get; set; } = null!;
    public DbSet<TeamExpense> TeamExpenses { get; set; } = null!;
    public DbSet<MatchVote> MatchVotes { get; set; } = null!;
    public DbSet<TeamChore> TeamChores { get; set; } = null!;
    public DbSet<MatchChoreAssignment> MatchChoreAssignments { get; set; } = null!;

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

        // Configurazione Club
        modelBuilder.Entity<Club>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.InviteCode).IsUnique();
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();
        });

        // Configurazione ClubMember
        modelBuilder.Entity<ClubMember>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.ClubId);
            // MySQL ammette piu' NULL in un indice unique: le anagrafiche senza account non collidono
            entity.HasIndex(e => new { e.ClubId, e.UserId }).IsUnique();
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();

            entity.HasOne(e => e.Club)
                .WithMany(c => c.Members)
                .HasForeignKey(e => e.ClubId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.User)
                .WithMany(u => u.ClubMemberships)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione Team
        modelBuilder.Entity<Team>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.ClubId);
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();
            entity.Property(e => e.Formato).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.RegimePagamentoDefault).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.ApplicaIscrizioneA).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.ApplicaTesseramentoA).HasConversion<string>().HasMaxLength(20);

            entity.HasOne(e => e.Club)
                .WithMany(c => c.Teams)
                .HasForeignKey(e => e.ClubId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione Season
        modelBuilder.Entity<Season>(entity =>
        {
            entity.HasKey(e => e.Id);
            // Il vincolo "una sola aperta per squadra" e applicativo, non di schema:
            // un indice filtrato non e portabile su MySQL
            entity.HasIndex(e => new { e.TeamId, e.Chiusa });
            entity.Property(e => e.Nome).HasMaxLength(50).IsRequired();

            entity.HasOne(e => e.Team)
                .WithMany(t => t.Seasons)
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione Player
        modelBuilder.Entity<Player>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.UserId }).IsUnique();

            entity.Property(e => e.Ruolo).HasConversion<string>();
            entity.Property(e => e.Posizione).HasConversion<string>().HasMaxLength(30);
            entity.Property(e => e.RegimePagamento).HasConversion<string>().HasMaxLength(20);

            entity.HasOne(e => e.ClubMember)
                .WithMany(m => m.Players)
                .HasForeignKey(e => e.ClubMemberId)
                .OnDelete(DeleteBehavior.SetNull);

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
            // Una partita non puo essere addebitata due volte alla stessa persona.
            // MySQL ammette piu NULL in un indice unique, quindi le quote fisse
            // (MatchId null) non si intralciano fra loro.
            entity.HasIndex(e => new { e.PlayerId, e.MatchId }).IsUnique();

            entity.Property(e => e.Tipo).HasConversion<string>().HasMaxLength(20);

            entity.HasIndex(e => new { e.TeamId, e.Pagato });

            // La voce appartiene alla squadra, non al giocatore: se il giocatore
            // viene cancellato la traccia contabile deve restare (SetNull), col
            // nome congelato nella riga. Solo la cancellazione della squadra
            // porta via anche i suoi conti.
            entity.HasOne(e => e.Team)
                .WithMany()
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Player)
                .WithMany(p => p.Payments)
                .HasForeignKey(e => e.PlayerId)
                .OnDelete(DeleteBehavior.SetNull);

            // SetNull e non Cascade: cancellare una partita non deve far sparire i soldi
            entity.HasOne(e => e.Match)
                .WithMany()
                .HasForeignKey(e => e.MatchId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(e => e.Season)
                .WithMany()
                .HasForeignKey(e => e.SeasonId)
                .OnDelete(DeleteBehavior.SetNull);

            // Era Restrict, e questo bloccava la cancellazione di un admin che
            // aveva registrato pagamenti: la richiesta finiva in errore FK.
            entity.HasOne(e => e.Admin)
                .WithMany()
                .HasForeignKey(e => e.AdminId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Configurazione Match
        modelBuilder.Entity<Match>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.NumeroGiornata });
            entity.HasIndex(e => new { e.TeamId, e.Data });

            entity.Property(e => e.Stato).HasConversion<string>();

            entity.HasIndex(e => e.SeasonId);

            entity.HasOne(e => e.Team)
                .WithMany(t => t.Matches)
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);

            // SetNull: archiviare non deve poter cancellare le partite
            entity.HasOne(e => e.Season)
                .WithMany(s => s.Matches)
                .HasForeignKey(e => e.SeasonId)
                .OnDelete(DeleteBehavior.SetNull);
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

            // SetNull e non Restrict: cancellare un admin che ha registrato
            // movimenti non deve fallire, il nome resta in AdminNome
            entity.HasOne(e => e.Admin)
                .WithMany()
                .HasForeignKey(e => e.AdminId)
                .OnDelete(DeleteBehavior.SetNull);
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
                .OnDelete(DeleteBehavior.SetNull);
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

        // Configurazione TeamDraft
        modelBuilder.Entity<TeamDraft>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => e.ShareCode).IsUnique();
            entity.Property(e => e.NomeTeam).HasMaxLength(100).IsRequired();
            entity.Property(e => e.Formato).HasConversion<string>().HasMaxLength(20);

            entity.HasOne(e => e.User)
                .WithMany(u => u.TeamDrafts)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione DraftCollaborator
        modelBuilder.Entity<DraftCollaborator>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamDraftId, e.UserId }).IsUnique();
            entity.HasIndex(e => e.UserId);

            entity.HasOne(e => e.TeamDraft)
                .WithMany(d => d.Collaborators)
                .HasForeignKey(e => e.TeamDraftId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione DraftCandidate
        modelBuilder.Entity<DraftCandidate>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.TeamDraftId);
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();
            entity.Property(e => e.Stato).HasConversion<string>();
            entity.Property(e => e.Posizione).HasConversion<string>();

            entity.HasOne(e => e.TeamDraft)
                .WithMany(d => d.Candidates)
                .HasForeignKey(e => e.TeamDraftId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione PushDevice
        modelBuilder.Entity<PushDevice>(entity =>
        {
            entity.HasKey(e => e.Id);
            // L'endpoint identifica univocamente il browser presso il push service
            entity.HasIndex(e => e.Endpoint).IsUnique();
            entity.HasIndex(e => e.UserId);
            entity.Property(e => e.Endpoint).HasMaxLength(500).IsRequired();

            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione NotificationPreference
        modelBuilder.Entity<NotificationPreference>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.UserId, e.Kind }).IsUnique();
            entity.Property(e => e.Kind).HasConversion<string>().HasMaxLength(30);

            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione NotificationOutboxItem
        modelBuilder.Entity<NotificationOutboxItem>(entity =>
        {
            entity.HasKey(e => e.Id);
            // Il dispatcher pesca per stato, momento di invio e ordine di inserimento
            entity.HasIndex(e => new { e.Stato, e.ScheduledFor, e.Id });
            entity.Property(e => e.Kind).HasConversion<string>().HasMaxLength(30);
            entity.Property(e => e.Stato).HasConversion<string>().HasMaxLength(20);

            entity.HasOne(e => e.Recipient)
                .WithMany()
                .HasForeignKey(e => e.RecipientUserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione TeamExpense (uscite di cassa)
        modelBuilder.Entity<TeamExpense>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.TeamId, e.SeasonId });
            entity.HasIndex(e => e.MatchId);
            entity.Property(e => e.Categoria).HasConversion<string>().HasMaxLength(20);

            entity.HasOne(e => e.Team).WithMany().HasForeignKey(e => e.TeamId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Season).WithMany().HasForeignKey(e => e.SeasonId).OnDelete(DeleteBehavior.SetNull);
            // La partita puo' sparire, l'uscita resta nei conti
            entity.HasOne(e => e.Match).WithMany().HasForeignKey(e => e.MatchId).OnDelete(DeleteBehavior.SetNull);
        });

        // Configurazione MatchVote (migliore in campo)
        modelBuilder.Entity<MatchVote>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MatchId, e.VoterPlayerId }).IsUnique();
            entity.HasIndex(e => e.VotedPlayerId);

            entity.HasOne(e => e.Match).WithMany().HasForeignKey(e => e.MatchId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Voter).WithMany().HasForeignKey(e => e.VoterPlayerId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Voted).WithMany().HasForeignKey(e => e.VotedPlayerId).OnDelete(DeleteBehavior.Cascade);
        });

        // Configurazione TeamChore / MatchChoreAssignment (turni)
        modelBuilder.Entity<TeamChore>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.TeamId);
            entity.HasOne(e => e.Team).WithMany().HasForeignKey(e => e.TeamId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<MatchChoreAssignment>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => new { e.MatchId, e.ChoreId }).IsUnique();
            entity.HasIndex(e => e.PlayerId);

            entity.HasOne(e => e.Match).WithMany().HasForeignKey(e => e.MatchId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Chore).WithMany(c => c.Assignments).HasForeignKey(e => e.ChoreId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Player).WithMany().HasForeignKey(e => e.PlayerId).OnDelete(DeleteBehavior.SetNull);
        });

        // Configurazione PendingPlayer
        modelBuilder.Entity<PendingPlayer>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.TeamId);
            entity.Property(e => e.Nome).HasMaxLength(100).IsRequired();
            entity.Property(e => e.Posizione).HasConversion<string>();

            entity.HasOne(e => e.Team)
                .WithMany(t => t.PendingPlayers)
                .HasForeignKey(e => e.TeamId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
