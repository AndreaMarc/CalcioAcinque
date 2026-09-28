using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddColoreBrandTemaScuro : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "TemaScuro",
                table: "users",
                type: "tinyint(1)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ColoreBrand",
                table: "teams",
                type: "varchar(7)",
                maxLength: 7,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TemaScuro",
                table: "users");

            migrationBuilder.DropColumn(
                name: "ColoreBrand",
                table: "teams");
        }
    }
}
