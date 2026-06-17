using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace server.core.Migrations
{
    /// <inheritdoc />
    public partial class AddIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Users_Email",
                schema: "app",
                table: "Users",
                column: "Email");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Name",
                schema: "app",
                table: "Users",
                column: "Name");

            migrationBuilder.CreateIndex(
                name: "IX_ImportLog_Dataset_CompletedAt_Id",
                schema: "app",
                table: "ImportLog",
                columns: new[] { "Dataset", "CompletedAt", "Id" },
                descending: new[] { false, true, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Users_Email",
                schema: "app",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_Name",
                schema: "app",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_ImportLog_Dataset_CompletedAt_Id",
                schema: "app",
                table: "ImportLog");
        }
    }
}
