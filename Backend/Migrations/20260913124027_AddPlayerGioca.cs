using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayerGioca : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Gioca",
                table: "players",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: true);

            // Chi c'era prima gioca: la colonna nasce per marcare lo staff, non i giocatori
            migrationBuilder.Sql("UPDATE players SET Gioca = 1;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Gioca",
                table: "players");
        }
    }
}
