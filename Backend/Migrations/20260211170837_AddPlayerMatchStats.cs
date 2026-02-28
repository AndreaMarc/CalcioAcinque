using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayerMatchStats : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Ammonizioni",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Assist",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Autogoal",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Espulsioni",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Goal",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GoalSubiti",
                table: "match_attendance",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MinutiGiocati",
                table: "match_attendance",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Ammonizioni",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "Assist",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "Autogoal",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "Espulsioni",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "Goal",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "GoalSubiti",
                table: "match_attendance");

            migrationBuilder.DropColumn(
                name: "MinutiGiocati",
                table: "match_attendance");
        }
    }
}
