using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class EccezioniEconomicheGiocatore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CostoPartitaPersonale",
                table: "players",
                type: "decimal(10,2)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GettoniPerStagione",
                table: "players",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "QuotaIscrizionePersonale",
                table: "players",
                type: "decimal(10,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "QuotaTesseramentoPersonale",
                table: "players",
                type: "decimal(10,2)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "UsaGettoni",
                table: "players",
                type: "tinyint(1)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CostoPartitaPersonale",
                table: "players");

            migrationBuilder.DropColumn(
                name: "GettoniPerStagione",
                table: "players");

            migrationBuilder.DropColumn(
                name: "QuotaIscrizionePersonale",
                table: "players");

            migrationBuilder.DropColumn(
                name: "QuotaTesseramentoPersonale",
                table: "players");

            migrationBuilder.DropColumn(
                name: "UsaGettoni",
                table: "players");
        }
    }
}
