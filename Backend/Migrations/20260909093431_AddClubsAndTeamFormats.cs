using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddClubsAndTeamFormats : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ClubId",
                table: "teams",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "CostoPartita",
                table: "teams",
                type: "decimal(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Formato",
                table: "teams",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "CalcioA5")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "GiocatoriInCampo",
                table: "teams",
                type: "int",
                nullable: false,
                defaultValue: 5);

            migrationBuilder.AddColumn<int>(
                name: "MaxConvocati",
                table: "teams",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MinutiPerTempo",
                table: "teams",
                type: "int",
                nullable: false,
                defaultValue: 25);

            migrationBuilder.AddColumn<int>(
                name: "NumeroTempi",
                table: "teams",
                type: "int",
                nullable: false,
                defaultValue: 2);

            migrationBuilder.AddColumn<decimal>(
                name: "QuotaIscrizione",
                table: "teams",
                type: "decimal(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "QuotaTesseramento",
                table: "teams",
                type: "decimal(10,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "ClubMemberId",
                table: "players",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NumeroMaglia",
                table: "players",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Posizione",
                table: "players",
                type: "varchar(30)",
                maxLength: 30,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "clubs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Nome = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    InviteCode = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_clubs", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "club_members",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    ClubId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: true),
                    Nome = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Soprannome = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Telefono = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DataNascita = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Note = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_club_members", x => x.Id);
                    table.ForeignKey(
                        name: "FK_club_members_clubs_ClubId",
                        column: x => x.ClubId,
                        principalTable: "clubs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_club_members_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_teams_ClubId",
                table: "teams",
                column: "ClubId");

            migrationBuilder.CreateIndex(
                name: "IX_players_ClubMemberId",
                table: "players",
                column: "ClubMemberId");

            migrationBuilder.CreateIndex(
                name: "IX_club_members_ClubId",
                table: "club_members",
                column: "ClubId");

            migrationBuilder.CreateIndex(
                name: "IX_club_members_ClubId_UserId",
                table: "club_members",
                columns: new[] { "ClubId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_club_members_UserId",
                table: "club_members",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_clubs_InviteCode",
                table: "clubs",
                column: "InviteCode",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_players_club_members_ClubMemberId",
                table: "players",
                column: "ClubMemberId",
                principalTable: "club_members",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_teams_clubs_ClubId",
                table: "teams",
                column: "ClubId",
                principalTable: "clubs",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            // ------------------------------------------------------------------
            // Backfill: le squadre preesistenti sono tutte calcio a 5 e diventano
            // ognuna la propria societa'. I loro giocatori entrano nell'anagrafica
            // di quella societa', cosi' Player.ClubMemberId non resta mai vuoto.
            // ------------------------------------------------------------------

            migrationBuilder.Sql("UPDATE teams SET Formato = 'CalcioA5' WHERE Formato IS NULL OR Formato = '';");
            migrationBuilder.Sql("UPDATE teams SET GiocatoriInCampo = 5 WHERE GiocatoriInCampo = 0;");
            migrationBuilder.Sql("UPDATE teams SET MinutiPerTempo = 25 WHERE MinutiPerTempo = 0;");
            migrationBuilder.Sql("UPDATE teams SET NumeroTempi = 2 WHERE NumeroTempi = 0;");
            migrationBuilder.Sql("UPDATE teams SET MaxConvocati = 12 WHERE MaxConvocati IS NULL;");

            // Colonne d'appoggio: servono per ricollegare le righe appena inserite
            // alle originali, cosa che un INSERT ... SELECT non permette di fare.
            migrationBuilder.Sql("ALTER TABLE clubs ADD COLUMN _legacy_team_id INT NULL;");

            migrationBuilder.Sql(@"
                INSERT INTO clubs (Nome, InviteCode, CreatedAt, _legacy_team_id)
                SELECT t.Nome,
                       UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12)),
                       UTC_TIMESTAMP(),
                       t.Id
                FROM teams t
                WHERE t.ClubId IS NULL;");

            migrationBuilder.Sql(@"
                UPDATE teams t
                JOIN clubs c ON c._legacy_team_id = t.Id
                SET t.ClubId = c.Id
                WHERE t.ClubId IS NULL;");

            migrationBuilder.Sql("ALTER TABLE club_members ADD COLUMN _legacy_player_id INT NULL;");

            migrationBuilder.Sql(@"
                INSERT INTO club_members (ClubId, UserId, Nome, Soprannome, Telefono, CreatedAt, _legacy_player_id)
                SELECT t.ClubId, p.UserId, p.Nome, p.Soprannome, p.Telefono, p.CreatedAt, p.Id
                FROM players p
                JOIN teams t ON t.Id = p.TeamId
                WHERE p.ClubMemberId IS NULL AND t.ClubId IS NOT NULL;");

            migrationBuilder.Sql(@"
                UPDATE players p
                JOIN club_members m ON m._legacy_player_id = p.Id
                SET p.ClubMemberId = m.Id
                WHERE p.ClubMemberId IS NULL;");

            migrationBuilder.Sql("ALTER TABLE club_members DROP COLUMN _legacy_player_id;");
            migrationBuilder.Sql("ALTER TABLE clubs DROP COLUMN _legacy_team_id;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_players_club_members_ClubMemberId",
                table: "players");

            migrationBuilder.DropForeignKey(
                name: "FK_teams_clubs_ClubId",
                table: "teams");

            migrationBuilder.DropTable(
                name: "club_members");

            migrationBuilder.DropTable(
                name: "clubs");

            migrationBuilder.DropIndex(
                name: "IX_teams_ClubId",
                table: "teams");

            migrationBuilder.DropIndex(
                name: "IX_players_ClubMemberId",
                table: "players");

            migrationBuilder.DropColumn(
                name: "ClubId",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "CostoPartita",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "Formato",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "GiocatoriInCampo",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "MaxConvocati",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "MinutiPerTempo",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "NumeroTempi",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "QuotaIscrizione",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "QuotaTesseramento",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "ClubMemberId",
                table: "players");

            migrationBuilder.DropColumn(
                name: "NumeroMaglia",
                table: "players");

            migrationBuilder.DropColumn(
                name: "Posizione",
                table: "players");
        }
    }
}
