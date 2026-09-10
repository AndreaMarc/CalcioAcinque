using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class MovimentiSopravvivonoAllAdmin : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_announcements_players_AuthorId",
                table: "announcements");

            migrationBuilder.DropForeignKey(
                name: "FK_token_transactions_players_AdminId",
                table: "token_transactions");

            migrationBuilder.AlterColumn<int>(
                name: "AdminId",
                table: "token_transactions",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<string>(
                name: "AdminNome",
                table: "token_transactions",
                type: "varchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AlterColumn<int>(
                name: "AuthorId",
                table: "announcements",
                type: "int",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "int");

            migrationBuilder.AddColumn<string>(
                name: "AutoreNome",
                table: "announcements",
                type: "varchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "")
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<string>(
                name: "AutoreSoprannome",
                table: "announcements",
                type: "varchar(100)",
                maxLength: 100,
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            // I nomi congelati vanno riempiti sulle righe esistenti: da qui in poi
            // la lettura non passa piu' dalla join con players.
            migrationBuilder.Sql(@"
                UPDATE token_transactions tt
                JOIN players p ON p.Id = tt.AdminId
                SET tt.AdminNome = p.Nome;");

            migrationBuilder.Sql(@"
                UPDATE announcements a
                JOIN players p ON p.Id = a.AuthorId
                SET a.AutoreNome = p.Nome, a.AutoreSoprannome = p.Soprannome;");

            migrationBuilder.AddForeignKey(
                name: "FK_announcements_players_AuthorId",
                table: "announcements",
                column: "AuthorId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_token_transactions_players_AdminId",
                table: "token_transactions",
                column: "AdminId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_announcements_players_AuthorId",
                table: "announcements");

            migrationBuilder.DropForeignKey(
                name: "FK_token_transactions_players_AdminId",
                table: "token_transactions");

            migrationBuilder.DropColumn(
                name: "AdminNome",
                table: "token_transactions");

            migrationBuilder.DropColumn(
                name: "AutoreNome",
                table: "announcements");

            migrationBuilder.DropColumn(
                name: "AutoreSoprannome",
                table: "announcements");

            migrationBuilder.AlterColumn<int>(
                name: "AdminId",
                table: "token_transactions",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "AuthorId",
                table: "announcements",
                type: "int",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_announcements_players_AuthorId",
                table: "announcements",
                column: "AuthorId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_token_transactions_players_AdminId",
                table: "token_transactions",
                column: "AdminId",
                principalTable: "players",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
