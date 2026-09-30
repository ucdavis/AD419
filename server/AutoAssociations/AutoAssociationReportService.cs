using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models.AutoAssociations;

namespace Server.AutoAssociations;

/// <summary>
/// Read-only reports over the auto-association staging tables. The tables hold
/// one cycle (rebuilt whole by BuildAutoAssociations), so nothing here filters
/// by date. Lists are summary sized; the client pages them.
/// </summary>
public sealed class AutoAssociationReportService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IAutoAssociationReportService
{
    // One row per NIFA project. Projects is at NIFA x AE grain, so collapse.
    private const string ProjectInfoCte = """
        WITH ProjectInfo AS
        (
            SELECT
                [AccessionNumber],
                MIN([NifaProjectNumber]) AS [NifaProjectNumber],
                MAX([Title]) AS [Title],
                MAX([ProjectDirector]) AS [ProjectDirector],
                MIN([Sfn]) AS [Sfn]
            FROM [data].[Projects]
            GROUP BY [AccessionNumber]
        )
        """;

    public async Task<AutoAssociationBuildDto?> GetBuildAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var row = await connection.QuerySingleOrDefaultAsync<AutoAssociationBuildRow>(Command(
            """
            SELECT TOP (1) [BuildId], [CycleStart], [CycleEnd], [BuiltAt],
                   [SummaryRows], [AssociationRows], [ExcludedProjects], [Misclassified204Rows]
            FROM [data].[AutoAssociationBuilds]
            ORDER BY [BuildId] DESC
            """, cancellationToken));
        if (row is null)
        {
            return null;
        }

        return new AutoAssociationBuildDto(
            row.BuildId,
            DateOnly.FromDateTime(row.CycleStart),
            DateOnly.FromDateTime(row.CycleEnd),
            row.BuiltAt,
            row.SummaryRows,
            row.AssociationRows,
            row.ExcludedProjects,
            row.Misclassified204Rows);
    }

    private sealed record AutoAssociationBuildRow(int BuildId, DateTime CycleStart, DateTime CycleEnd, DateTime BuiltAt, int SummaryRows, int AssociationRows, int ExcludedProjects, int Misclassified204Rows);

    public Task<Rule204ReportDto> GetRule204Async(CancellationToken cancellationToken) =>
        throw new NotImplementedException();

    public Task<Rule20xReportDto> GetRule20xAsync(CancellationToken cancellationToken) =>
        throw new NotImplementedException();

    public Task<Rule220ReportDto> GetRule220Async(CancellationToken cancellationToken) =>
        throw new NotImplementedException();

    public async Task<IReadOnlyList<ExcludedProjectDto>> GetExcludedProjectsAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var rows = await connection.QueryAsync<ExcludedProjectDto>(Command(
            ProjectInfoCte + """
            SELECT
                x.[AccessionNumber],
                x.[NifaProjectNumber],
                p.[Title],
                p.[ProjectDirector],
                (
                    SELECT STRING_AGG(ae.[AEProjectNumber], ', ') WITHIN GROUP (ORDER BY ae.[AEProjectNumber])
                    FROM (SELECT DISTINCT [AEProjectNumber] FROM [data].[Projects] WHERE [AccessionNumber] = x.[AccessionNumber] AND [AEProjectNumber] IS NOT NULL) ae
                ) AS [AeProjects],
                x.[Total]
            FROM [data].[AutoAssociationExcludedProjects] x
            LEFT JOIN ProjectInfo p ON p.[AccessionNumber] = x.[AccessionNumber]
            ORDER BY x.[AccessionNumber]
            """, cancellationToken));
        return rows.ToList();
    }

    public async Task<IReadOnlyList<FteOverOneDto>> GetFteOverOneAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var rows = await connection.QueryAsync<FteOverOneDto>(Command(
            """
            SELECT [EmployeeId], MAX([EmployeeName]) AS [EmployeeName], SUM([Fte]) AS [Fte], COUNT(*) AS [RowCount]
            FROM [data].[ExpenseSummary]
            WHERE [Source] = N'UCPath' AND [EmployeeId] IS NOT NULL
            GROUP BY [EmployeeId]
            HAVING SUM([Fte]) > 1
            ORDER BY SUM([Fte]) DESC, [EmployeeId]
            """, cancellationToken));
        return rows.ToList();
    }

    public async Task<IReadOnlyList<PreAssociationTotalDto>> GetPreAssociationTotalsAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);
        var rows = await connection.QueryAsync<PreAssociationTotalDto>(Command(
            """
            SELECT
                e.[OrgR],
                e.[FinancialDepartment],
                COALESCE(NULLIF(cs.[ValueDesc], ''), NULLIF(cs.[Description], '')) AS [FinancialDepartmentName],
                e.[ExpenseSfn],
                sf.[Label] AS [SfnLabel],
                SUM(e.[Expenses]) AS [Expenses],
                SUM(e.[Fte]) AS [Fte]
            FROM [data].[ExpenseSummary] e
            LEFT JOIN [data].[ChartSegments] cs ON cs.[SegmentName] = 'FinancialDepartment' AND cs.[Code] = e.[FinancialDepartment]
            LEFT JOIN [data].[Sfns] sf ON sf.[Sfn] = e.[ExpenseSfn]
            GROUP BY e.[OrgR], e.[FinancialDepartment], cs.[ValueDesc], cs.[Description], e.[ExpenseSfn], sf.[Label]
            ORDER BY e.[OrgR], e.[FinancialDepartment], e.[ExpenseSfn]
            """, cancellationToken));
        return rows.ToList();
    }

    internal async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        var connectionString = DataDbConnection.Resolve(configuration, dataDbContext.Database.GetConnectionString());
        var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    internal static CommandDefinition Command(string sql, CancellationToken cancellationToken, object? parameters = null) =>
        new(sql, parameters, commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken);
}
