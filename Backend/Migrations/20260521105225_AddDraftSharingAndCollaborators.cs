using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddDraftSharingAndCollaborators : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // MySQL blocca DROP INDEX se l'indice è usato da una FK.
            // Droppo la FK, ricreo l'indice non-unique, riaggancio la FK.
            migrationBuilder.Sql("ALTER TABLE `team_drafts` DROP FOREIGN KEY `FK_team_drafts_users_UserId`;");
            migrationBuilder.Sql("ALTER TABLE `team_drafts` DROP INDEX `IX_team_drafts_UserId`;");

            migrationBuilder.AddColumn<string>(
                name: "ShareCode",
                table: "team_drafts",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "draft_collaborators",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    TeamDraftId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    IsOwner = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    JoinedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_draft_collaborators", x => x.Id);
                    table.ForeignKey(
                        name: "FK_draft_collaborators_team_drafts_TeamDraftId",
                        column: x => x.TeamDraftId,
                        principalTable: "team_drafts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_draft_collaborators_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_team_drafts_ShareCode",
                table: "team_drafts",
                column: "ShareCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_team_drafts_UserId",
                table: "team_drafts",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_team_drafts_users_UserId",
                table: "team_drafts",
                column: "UserId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.CreateIndex(
                name: "IX_draft_collaborators_TeamDraftId_UserId",
                table: "draft_collaborators",
                columns: new[] { "TeamDraftId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_draft_collaborators_UserId",
                table: "draft_collaborators",
                column: "UserId");

            // Backfill: per ogni draft esistente genera ShareCode e crea collaborator owner.
            // Lo ShareCode è di 8 caratteri (alphanum, parte alta di un UUID4).
            migrationBuilder.Sql(@"
                UPDATE team_drafts
                SET ShareCode = UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 8))
                WHERE ShareCode IS NULL;
            ");
            migrationBuilder.Sql(@"
                INSERT INTO draft_collaborators (TeamDraftId, UserId, IsOwner, JoinedAt)
                SELECT d.Id, d.UserId, 1, d.CreatedAt
                FROM team_drafts d
                LEFT JOIN draft_collaborators c
                  ON c.TeamDraftId = d.Id AND c.UserId = d.UserId
                WHERE c.Id IS NULL;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "draft_collaborators");

            migrationBuilder.DropIndex(
                name: "IX_team_drafts_ShareCode",
                table: "team_drafts");

            migrationBuilder.DropIndex(
                name: "IX_team_drafts_UserId",
                table: "team_drafts");

            migrationBuilder.DropColumn(
                name: "ShareCode",
                table: "team_drafts");

            migrationBuilder.CreateIndex(
                name: "IX_team_drafts_UserId",
                table: "team_drafts",
                column: "UserId",
                unique: true);
        }
    }
}
