using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CalcioAcinque.Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddPromemoriaPartita : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_notification_outbox_Stato_Id",
                table: "notification_outbox");

            migrationBuilder.AddColumn<int>(
                name: "OrePromemoriaPartita",
                table: "teams",
                type: "int",
                nullable: false,
                defaultValue: 24);

            // Le squadre esistenti partono col promemoria attivo a 24 ore:
            // e la feature che e stata chiesta, non un opt-in da scoprire.
            migrationBuilder.Sql("UPDATE teams SET OrePromemoriaPartita = 24 WHERE OrePromemoriaPartita = 0;");

            migrationBuilder.AddColumn<DateTime>(
                name: "ScheduledFor",
                table: "notification_outbox",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PromemoriaInviatoAt",
                table: "matches",
                type: "datetime(6)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_notification_outbox_Stato_ScheduledFor_Id",
                table: "notification_outbox",
                columns: new[] { "Stato", "ScheduledFor", "Id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_notification_outbox_Stato_ScheduledFor_Id",
                table: "notification_outbox");

            migrationBuilder.DropColumn(
                name: "OrePromemoriaPartita",
                table: "teams");

            migrationBuilder.DropColumn(
                name: "ScheduledFor",
                table: "notification_outbox");

            migrationBuilder.DropColumn(
                name: "PromemoriaInviatoAt",
                table: "matches");

            migrationBuilder.CreateIndex(
                name: "IX_notification_outbox_Stato_Id",
                table: "notification_outbox",
                columns: new[] { "Stato", "Id" });
        }
    }
}
