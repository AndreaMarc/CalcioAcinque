using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddStagioni : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SeasonId",
                table: "player_payments",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SeasonId",
                table: "matches",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "seasons",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    TeamId = table.Column<int>(type: "int", nullable: false),
                    Nome = table.Column<string>(type: "varchar(50)", maxLength: 50, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    DataInizio = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    DataFine = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Chiusa = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Note = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_seasons", x => x.Id);
                    table.ForeignKey(
                        name: "FK_seasons_teams_TeamId",
                        column: x => x.TeamId,
                        principalTable: "teams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_player_payments_SeasonId",
                table: "player_payments",
                column: "SeasonId");

            migrationBuilder.CreateIndex(
                name: "IX_matches_SeasonId",
                table: "matches",
                column: "SeasonId");

            migrationBuilder.CreateIndex(
                name: "IX_seasons_TeamId_Chiusa",
                table: "seasons",
                columns: new[] { "TeamId", "Chiusa" });

            // ------------------------------------------------------------------
            // Backfill: ogni squadra riceve una stagione aperta, e tutto lo
            // storico esistente le viene assegnato. Serve una colonna d appoggio
            // per ricollegare le stagioni inserite alle squadre, come nella
            // migration delle societa.
            // ------------------------------------------------------------------

            migrationBuilder.Sql("ALTER TABLE seasons ADD COLUMN _legacy_team_id INT NULL;");

            migrationBuilder.Sql(@"
                INSERT INTO seasons (TeamId, Nome, DataInizio, Chiusa, CreatedAt, _legacy_team_id)
                SELECT t.Id,
                       CONCAT(
                           IF(MONTH(UTC_TIMESTAMP()) >= 7, YEAR(UTC_TIMESTAMP()), YEAR(UTC_TIMESTAMP()) - 1),
                           '/',
                           LPAD(MOD(IF(MONTH(UTC_TIMESTAMP()) >= 7, YEAR(UTC_TIMESTAMP()) + 1, YEAR(UTC_TIMESTAMP())), 100), 2, '0')
                       ),
                       UTC_TIMESTAMP(), 0, UTC_TIMESTAMP(), t.Id
                FROM teams t;");

            migrationBuilder.Sql(@"
                UPDATE matches m
                JOIN seasons s ON s._legacy_team_id = m.TeamId
                SET m.SeasonId = s.Id
                WHERE m.SeasonId IS NULL;");

            migrationBuilder.Sql(@"
                UPDATE player_payments pp
                JOIN seasons s ON s._legacy_team_id = pp.TeamId
                SET pp.SeasonId = s.Id
                WHERE pp.SeasonId IS NULL;");

            migrationBuilder.Sql("ALTER TABLE seasons DROP COLUMN _legacy_team_id;");

            migrationBuilder.AddForeignKey(
                name: "FK_matches_seasons_SeasonId",
                table: "matches",
                column: "SeasonId",
                principalTable: "seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_seasons_SeasonId",
                table: "player_payments",
                column: "SeasonId",
                principalTable: "seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_matches_seasons_SeasonId",
                table: "matches");

            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_seasons_SeasonId",
                table: "player_payments");

            migrationBuilder.DropTable(
                name: "seasons");

            migrationBuilder.DropIndex(
                name: "IX_player_payments_SeasonId",
                table: "player_payments");

            migrationBuilder.DropIndex(
                name: "IX_matches_SeasonId",
                table: "matches");

            migrationBuilder.DropColumn(
                name: "SeasonId",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "SeasonId",
                table: "matches");
        }
    }
}
