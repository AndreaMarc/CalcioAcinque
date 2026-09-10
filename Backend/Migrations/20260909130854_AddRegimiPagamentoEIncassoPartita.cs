using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddRegimiPagamentoEIncassoPartita : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ApplicaIscrizioneA",
                table: "teams",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "SoloStagionali")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "ApplicaTesseramentoA",
                table: "teams",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Tutti")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Iban",
                table: "teams",
                type: "varchar(34)",
                maxLength: 34,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "IntestatarioIban",
                table: "teams",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "MinutiMinimiPerAddebito",
                table: "teams",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "PaypalLink",
                table: "teams",
                type: "varchar(255)",
                maxLength: 255,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "RegimePagamentoDefault",
                table: "teams",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Stagionale")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "RegimePagamento",
                table: "players",
                type: "varchar(20)",
                maxLength: 20,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<DateTime>(
                name: "DichiaratoPagatoAt",
                table: "player_payments",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "MatchId",
                table: "player_payments",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Tipo",
                table: "player_payments",
                type: "varchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Altro")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "Iban",
                table: "clubs",
                type: "varchar(34)",
                maxLength: 34,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "IntestatarioIban",
                table: "clubs",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "PaypalLink",
                table: "clubs",
                type: "varchar(255)",
                maxLength: 255,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_player_payments_MatchId",
                table: "player_payments",
                column: "MatchId");

            migrationBuilder.CreateIndex(
                name: "IX_player_payments_PlayerId_MatchId",
                table: "player_payments",
                columns: new[] { "PlayerId", "MatchId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_matches_MatchId",
                table: "player_payments",
                column: "MatchId",
                principalTable: "matches",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
            // ------------------------------------------------------------------
            // Backfill. I default di colonna coprono le righe esistenti, ma li
            // riaffermo perche' EF li applica solo se la colonna nasce NOT NULL
            // con default: meglio essere espliciti su un DB di produzione.
            // ------------------------------------------------------------------

            migrationBuilder.Sql("UPDATE teams SET RegimePagamentoDefault = 'Stagionale' WHERE RegimePagamentoDefault IS NULL OR RegimePagamentoDefault = '';");
            migrationBuilder.Sql("UPDATE teams SET ApplicaIscrizioneA = 'SoloStagionali' WHERE ApplicaIscrizioneA IS NULL OR ApplicaIscrizioneA = '';");
            migrationBuilder.Sql("UPDATE teams SET ApplicaTesseramentoA = 'Tutti' WHERE ApplicaTesseramentoA IS NULL OR ApplicaTesseramentoA = '';");

            // Le voci gia' in tabella sono riconoscibili dalla descrizione canonica
            // usata da PaymentService.GenerateFeesAsync: si classificano cosi', il
            // resto resta 'Altro'.
            migrationBuilder.Sql("UPDATE player_payments SET Tipo = 'Iscrizione' WHERE Descrizione = 'Quota iscrizione';");
            migrationBuilder.Sql("UPDATE player_payments SET Tipo = 'Tesseramento' WHERE Descrizione = 'Quota tesseramento';");
            migrationBuilder.Sql("UPDATE player_payments SET Tipo = 'Altro' WHERE Tipo IS NULL OR Tipo = '';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_matches_MatchId",
                table: "player_payments");

            migrationBuilder.DropIndex(
                name: "IX_player_payments_MatchId",
                table: "player_payments");

            migrationBuilder.DropIndex(
                name: "IX_player_payments_PlayerId_MatchId",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "ApplicaIscrizioneA",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "ApplicaTesseramentoA",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "Iban",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "IntestatarioIban",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "MinutiMinimiPerAddebito",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "PaypalLink",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "RegimePagamentoDefault",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "RegimePagamento",
                table: "players");

            migrationBuilder.DropColumn(
                name: "DichiaratoPagatoAt",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "MatchId",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "Tipo",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "Iban",
                table: "clubs");

            migrationBuilder.DropColumn(
                name: "IntestatarioIban",
                table: "clubs");

            migrationBuilder.DropColumn(
                name: "PaypalLink",
                table: "clubs");
        }
    }
}
