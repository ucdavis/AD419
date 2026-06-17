using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace server.core.Migrations
{
    /// <inheritdoc />
    public partial class ImportLog_Dataset_Idx : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
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
                name: "IX_ImportLog_Dataset_CompletedAt_Id",
                schema: "app",
                table: "ImportLog");
        }
    }
}
