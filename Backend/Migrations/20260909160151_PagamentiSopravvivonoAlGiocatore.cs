using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class PagamentiSopravvivonoAlGiocatore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_players_AdminId",
                table: "player_payments");

            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_players_PlayerId",
                table: "player_payments");

            migrationBuilder.AlterColumn<int>(
                name: "PlayerId",
                table: "player_payments",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AlterColumn<int>(
                name: "AdminId",
                table: "player_payments",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<string>(
                name: "AdminNome",
                table: "player_payments",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "NomeGiocatore",
                table: "player_payments",
                type: "varchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "TeamId",
                table: "player_payments",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // ------------------------------------------------------------------
            // Backfill PRIMA delle foreign key: TeamId nasce NOT NULL con default 0
            // e la FK verso teams rifiuterebbe le righe esistenti.
            // ------------------------------------------------------------------

            migrationBuilder.Sql(@"
                UPDATE player_payments pp
                JOIN players p ON p.Id = pp.PlayerId
                SET pp.TeamId = p.TeamId,
                    pp.NomeGiocatore = p.Nome;");

            migrationBuilder.Sql(@"
                UPDATE player_payments pp
                JOIN players a ON a.Id = pp.AdminId
                SET pp.AdminNome = a.Nome;");

            // Rete di sicurezza: se una riga non ha trovato il giocatore resta
            // senza squadra e la FK salterebbe. Meglio accorgersene qui.
            migrationBuilder.Sql("DELETE FROM player_payments WHERE TeamId = 0;");

            migrationBuilder.CreateIndex(
                name: "IX_player_payments_TeamId_Pagato",
                table: "player_payments",
                columns: new[] { "TeamId", "Pagato" });

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_players_AdminId",
                table: "player_payments",
                column: "AdminId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_players_PlayerId",
                table: "player_payments",
                column: "PlayerId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_teams_TeamId",
                table: "player_payments",
                column: "TeamId",
                principalTable: "teams",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_players_AdminId",
                table: "player_payments");

            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_players_PlayerId",
                table: "player_payments");

            migrationBuilder.DropForeignKey(
                name: "FK_player_payments_teams_TeamId",
                table: "player_payments");

            migrationBuilder.DropIndex(
                name: "IX_player_payments_TeamId_Pagato",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "AdminNome",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "NomeGiocatore",
                table: "player_payments");

            migrationBuilder.DropColumn(
                name: "TeamId",
                table: "player_payments");

            migrationBuilder.AlterColumn<int>(
                name: "PlayerId",
                table: "player_payments",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "AdminId",
                table: "player_payments",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_players_AdminId",
                table: "player_payments",
                column: "AdminId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_player_payments_players_PlayerId",
                table: "player_payments",
                column: "PlayerId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
