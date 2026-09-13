using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddCassaMvpTurni : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "match_votes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    MatchId = table.Column<int>(type: "int", nullable: false),
                    VoterPlayerId = table.Column<int>(type: "int", nullable: false),
                    VotedPlayerId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_match_votes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_match_votes_matches_MatchId",
                        column: x => x.MatchId,
                        principalTable: "matches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_match_votes_players_VotedPlayerId",
                        column: x => x.VotedPlayerId,
                        principalTable: "players",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_match_votes_players_VoterPlayerId",
                        column: x => x.VoterPlayerId,
                        principalTable: "players",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "team_chores",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    TeamId = table.Column<int>(type: "int", nullable: false),
                    Nome = table.Column<string>(type: "varchar(60)", maxLength: 60, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Attivo = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Ordine = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_team_chores", x => x.Id);
                    table.ForeignKey(
                        name: "FK_team_chores_teams_TeamId",
                        column: x => x.TeamId,
                        principalTable: "teams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "team_expenses",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    TeamId = table.Column<int>(type: "int", nullable: false),
                    SeasonId = table.Column<int>(type: "int", nullable: true),
                    MatchId = table.Column<int>(type: "int", nullable: true),
                    Categoria = table.Column<string>(type: "varchar(20)", maxLength: 20, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Descrizione = table.Column<string>(type: "varchar(200)", maxLength: 200, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Importo = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
                    Data = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    Note = table.Column<string>(type: "varchar(500)", maxLength: 500, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    AdminId = table.Column<int>(type: "int", nullable: true),
                    AdminNome = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_team_expenses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_team_expenses_matches_MatchId",
                        column: x => x.MatchId,
                        principalTable: "matches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_team_expenses_seasons_SeasonId",
                        column: x => x.SeasonId,
                        principalTable: "seasons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_team_expenses_teams_TeamId",
                        column: x => x.TeamId,
                        principalTable: "teams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "match_chore_assignments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    MatchId = table.Column<int>(type: "int", nullable: false),
                    ChoreId = table.Column<int>(type: "int", nullable: false),
                    PlayerId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_match_chore_assignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_match_chore_assignments_matches_MatchId",
                        column: x => x.MatchId,
                        principalTable: "matches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_match_chore_assignments_players_PlayerId",
                        column: x => x.PlayerId,
                        principalTable: "players",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_match_chore_assignments_team_chores_ChoreId",
                        column: x => x.ChoreId,
                        principalTable: "team_chores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_match_chore_assignments_ChoreId",
                table: "match_chore_assignments",
                column: "ChoreId");

            migrationBuilder.CreateIndex(
                name: "IX_match_chore_assignments_MatchId_ChoreId",
                table: "match_chore_assignments",
                columns: new[] { "MatchId", "ChoreId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_match_chore_assignments_PlayerId",
                table: "match_chore_assignments",
                column: "PlayerId");

            migrationBuilder.CreateIndex(
                name: "IX_match_votes_MatchId_VoterPlayerId",
                table: "match_votes",
                columns: new[] { "MatchId", "VoterPlayerId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_match_votes_VotedPlayerId",
                table: "match_votes",
                column: "VotedPlayerId");

            migrationBuilder.CreateIndex(
                name: "IX_match_votes_VoterPlayerId",
                table: "match_votes",
                column: "VoterPlayerId");

            migrationBuilder.CreateIndex(
                name: "IX_team_chores_TeamId",
                table: "team_chores",
                column: "TeamId");

            migrationBuilder.CreateIndex(
                name: "IX_team_expenses_MatchId",
                table: "team_expenses",
                column: "MatchId");

            migrationBuilder.CreateIndex(
                name: "IX_team_expenses_SeasonId",
                table: "team_expenses",
                column: "SeasonId");

            migrationBuilder.CreateIndex(
                name: "IX_team_expenses_TeamId_SeasonId",
                table: "team_expenses",
                columns: new[] { "TeamId", "SeasonId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "match_chore_assignments");

            migrationBuilder.DropTable(
                name: "match_votes");

            migrationBuilder.DropTable(
                name: "team_expenses");

            migrationBuilder.DropTable(
                name: "team_chores");
        }
    }
}
