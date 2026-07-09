using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.ProjectList;

namespace Server.ProjectList;

public sealed class ProjectListService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IProjectListService
{
    public async Task<ProjectListResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        var rows = (await connection.QueryAsync<ProjectListRowDto>(new CommandDefinition(
            "[data].[GetProjectList]",
            new
            {
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            commandType: CommandType.StoredProcedure,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken))).ToList();

        var summaryCounts = await connection.QuerySingleAsync<ProjectListSummaryCounts>(new CommandDefinition(
            SummaryCountsSql,
            new
            {
                cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
                cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
            },
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        return ProjectListResponseFactory.Create(
            cycle,
            rows,
            summaryCounts.ActiveNifa,
            summaryCounts.AllNifa,
            summaryCounts.PgmRecords,
            summaryCounts.AlnCodes);
    }

    private const string SummaryCountsSql = """
        SELECT
            ActiveNifa = (
                SELECT COUNT(*)
                FROM [data].[ActiveProjects]
                WHERE ISNULL([ExcludeFromUi], 0) = 0
            ),
            AllNifa = (
                SELECT COUNT(*)
                FROM [data].[AllProjects]
                WHERE ([ProjectEndDate] IS NULL OR [ProjectEndDate] >= @cycleStart)
                  AND ([ProjectStartDate] IS NULL OR [ProjectStartDate] <= @cycleEnd)
            ),
            PgmRecords = (
                SELECT COUNT(*)
                FROM [data].[PGMProjects]
            ),
            AlnCodes = (
                SELECT COUNT(*)
                FROM [data].[AssistanceListingNumbers]
                WHERE [ProgramNumber] IS NOT NULL
            );
        """;

    private sealed record ProjectListSummaryCounts(
        int ActiveNifa,
        int AllNifa,
        int PgmRecords,
        int AlnCodes);
}
