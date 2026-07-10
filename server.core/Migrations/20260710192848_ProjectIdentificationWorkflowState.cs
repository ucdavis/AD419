using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace server.core.Migrations
{
    /// <inheritdoc />
    public partial class ProjectIdentificationWorkflowState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "WorkflowRun",
                schema: "app",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    FiscalYear = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    CycleStart = table.Column<DateOnly>(type: "date", nullable: false),
                    CycleEnd = table.Column<DateOnly>(type: "date", nullable: false),
                    IsCurrent = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CreatedByEntraId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedByName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    CreatedByEmail = table.Column<string>(type: "nvarchar(320)", maxLength: 320, nullable: true),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedByEntraId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedByName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    UpdatedByEmail = table.Column<string>(type: "nvarchar(320)", maxLength: 320, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkflowRun", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "WorkflowChecklistItemState",
                schema: "app",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    WorkflowRunId = table.Column<int>(type: "int", nullable: false),
                    ItemId = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    CompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CompletedByEntraId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CompletedByName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    CompletedByEmail = table.Column<string>(type: "nvarchar(320)", maxLength: 320, nullable: true),
                    SourceImportLogId = table.Column<int>(type: "int", nullable: true),
                    SourceKey = table.Column<string>(type: "nvarchar(160)", maxLength: 160, nullable: true),
                    SourceRows = table.Column<int>(type: "int", nullable: true),
                    SourceCompletedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WorkflowChecklistItemState", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WorkflowChecklistItemState_WorkflowRun_WorkflowRunId",
                        column: x => x.WorkflowRunId,
                        principalSchema: "app",
                        principalTable: "WorkflowRun",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WorkflowChecklistItemState_WorkflowRunId_ItemId",
                schema: "app",
                table: "WorkflowChecklistItemState",
                columns: new[] { "WorkflowRunId", "ItemId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WorkflowRun_IsCurrent",
                schema: "app",
                table: "WorkflowRun",
                column: "IsCurrent");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WorkflowChecklistItemState",
                schema: "app");

            migrationBuilder.DropTable(
                name: "WorkflowRun",
                schema: "app");
        }
    }
}
