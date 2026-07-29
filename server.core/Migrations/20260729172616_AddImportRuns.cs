using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace server.core.Migrations
{
    /// <inheritdoc />
    public partial class AddImportRuns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ImportRun",
                schema: "app",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CycleStart = table.Column<DateOnly>(type: "date", nullable: false),
                    CycleEnd = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    TriggeredByEntraId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    TriggeredByName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    TriggeredByEmail = table.Column<string>(type: "nvarchar(320)", maxLength: 320, nullable: true),
                    StartedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ImportRun", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ImportRunStage",
                schema: "app",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ImportRunId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Ordinal = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    RowCount = table.Column<int>(type: "int", nullable: true),
                    StartedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    ErrorDetail = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ImportRunStage", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ImportRunStage_ImportRun_ImportRunId",
                        column: x => x.ImportRunId,
                        principalSchema: "app",
                        principalTable: "ImportRun",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ImportRun_Status",
                schema: "app",
                table: "ImportRun",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_ImportRunStage_ImportRunId",
                schema: "app",
                table: "ImportRunStage",
                column: "ImportRunId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ImportRunStage",
                schema: "app");

            migrationBuilder.DropTable(
                name: "ImportRun",
                schema: "app");
        }
    }
}
