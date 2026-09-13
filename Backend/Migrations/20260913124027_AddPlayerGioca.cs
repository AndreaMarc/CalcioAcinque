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
                defaultValue: false);
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
