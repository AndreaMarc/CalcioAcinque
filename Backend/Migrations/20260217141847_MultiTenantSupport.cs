using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class MultiTenantSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_players_users_UserId",
                table: "players");

            migrationBuilder.DropIndex(
                name: "IX_players_UserId",
                table: "players");

            migrationBuilder.AddColumn<string>(
                name: "InviteCode",
                table: "teams",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_players_UserId",
                table: "players",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_players_users_UserId",
                table: "players",
                column: "UserId",
                principalTable: "users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_players_UserId",
                table: "players");

            migrationBuilder.DropColumn(
                name: "InviteCode",
                table: "teams");

            migrationBuilder.CreateIndex(
                name: "IX_players_UserId",
                table: "players",
                column: "UserId",
                unique: true);
        }
    }
}
