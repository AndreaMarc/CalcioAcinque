using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddFormatoToTeamDraft : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Formato",
                table: "team_drafts",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "CalcioA5")
                .Annotation("MySql:CharSet", "utf8mb4");

            // I draft in corso erano tutti pianificati per il calcio a 5
            migrationBuilder.Sql("UPDATE team_drafts SET Formato = 'CalcioA5' WHERE Formato IS NULL OR Formato = '';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Formato",
                table: "team_drafts");
        }
    }
}
