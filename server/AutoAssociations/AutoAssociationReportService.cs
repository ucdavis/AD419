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

    public async Task<Rule204ReportDto> GetRule204Async(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);

        var projects = (await connection.QueryAsync<AssociatedProjectDto>(Command(
            ProjectInfoCte + """
            , AeProjects AS
            (
                SELECT d.[AccessionNumber], STRING_AGG(d.[AeProject], ', ') WITHIN GROUP (ORDER BY d.[AeProject]) AS [AeProjects]
                FROM (SELECT DISTINCT [AccessionNumber], [AeProject] FROM [data].[StagedAssociations] WHERE [Rule] = N'204') d
                GROUP BY d.[AccessionNumber]
            )
            SELECT
                s.[AccessionNumber],
                p.[NifaProjectNumber],
                p.[Title],
                p.[ProjectDirector],
                ae.[AeProjects],
                SUM(s.[Expenses]) AS [Expenses],
                SUM(s.[Fte]) AS [Fte]
            FROM [data].[StagedAssociations] s
            LEFT JOIN ProjectInfo p ON p.[AccessionNumber] = s.[AccessionNumber]
            LEFT JOIN AeProjects ae ON ae.[AccessionNumber] = s.[AccessionNumber]
            WHERE s.[Rule] = N'204'
            GROUP BY s.[AccessionNumber], p.[NifaProjectNumber], p.[Title], p.[ProjectDirector], ae.[AeProjects]
            ORDER BY s.[AccessionNumber]
            """, cancellationToken))).ToList();

        // A 204 expense stays unassociated when it is misclassified (no 204
        // project owns its AE project), when every 204 project owning its AE
        // project is excluded under $100, or otherwise.
        var unassociated = (await connection.QueryAsync<UnassociatedExpenseDto>(Command(
            """
            SELECT
                e.[ExpenseId], e.[Source], e.[Project], e.[Fund], e.[FinancialDepartment], e.[OrgR],
                e.[EmployeeId], e.[EmployeeName], e.[ExpenseSfn], e.[Expenses], e.[Fte],
                CASE
                    WHEN e.[RuleExclusion] = N'Misclassified204' THEN N'Misclassified204'
                    WHEN e.[Project] IS NULL THEN N'NoAeProject'
                    WHEN EXISTS
                    (
                        SELECT 1 FROM [data].[Projects] p
                        WHERE p.[Sfn] = '204' AND p.[AEProjectNumber] = e.[Project]
                    )
                    AND NOT EXISTS
                    (
                        SELECT 1 FROM [data].[Projects] p
                        WHERE p.[Sfn] = '204' AND p.[AEProjectNumber] = e.[Project]
                          AND NOT EXISTS (SELECT 1 FROM [data].[AutoAssociationExcludedProjects] x WHERE x.[AccessionNumber] = p.[AccessionNumber])
                    ) THEN N'ProjectExcluded'
                    ELSE N'NoRuleMatched'
                END AS [Reason]
            FROM [data].[ExpenseSummary] e
            WHERE e.[ExpenseSfn] = '204'
              AND NOT EXISTS (SELECT 1 FROM [data].[StagedAssociations] s WHERE s.[ExpenseId] = e.[ExpenseId])
            ORDER BY e.[Project], e.[ExpenseId]
            """, cancellationToken))).ToList();

        var misclassified = unassociated.Where(row => row.Reason == "Misclassified204").ToList();
        return new Rule204ReportDto(projects, unassociated, misclassified);
    }

    public async Task<Rule20xReportDto> GetRule20xAsync(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);

        var pis = (await connection.QueryAsync<Rule20xPiRow>(Command(
            """
            SELECT
                s.[ExpenseSfn] AS [Sfn],
                e.[EmployeeId],
                MAX(e.[EmployeeName]) AS [EmployeeName],
                COUNT(DISTINCT s.[AccessionNumber]) AS [ProjectCount],
                SUM(s.[Expenses]) AS [Expenses],
                SUM(s.[Fte]) AS [Fte]
            FROM [data].[StagedAssociations] s
            JOIN [data].[ExpenseSummary] e ON e.[ExpenseId] = s.[ExpenseId]
            WHERE s.[Rule] = N'20x'
            GROUP BY s.[ExpenseSfn], e.[EmployeeId]
            ORDER BY s.[ExpenseSfn], e.[EmployeeId]
            """, cancellationToken))).ToList();

        var projectCounts = (await connection.QueryAsync<SfnCountRow>(Command(
            """
            SELECT [ExpenseSfn] AS [Sfn], COUNT(DISTINCT [AccessionNumber]) AS [ProjectCount]
            FROM [data].[StagedAssociations]
            WHERE [Rule] = N'20x'
            GROUP BY [ExpenseSfn]
            """, cancellationToken))).ToDictionary(row => row.Sfn, row => row.ProjectCount);

        var labels = (await connection.QueryAsync<SfnLabelRow>(Command(
            "SELECT [Sfn], [Label] FROM [data].[Sfns] WHERE [Sfn] IN ('201', '202', '205')", cancellationToken)))
            .ToDictionary(row => row.Sfn, row => row.Label);

        var sfns = new List<Rule20xSfnDto>();
        foreach (var sfn in new[] { "201", "202", "205" })
        {
            var sfnPis = pis
                .Where(row => row.Sfn == sfn)
                .Select(row => new Rule20xPiDto(row.EmployeeId, row.EmployeeName, row.ProjectCount, row.Expenses, row.Fte))
                .ToList();
            sfns.Add(new Rule20xSfnDto(
                sfn,
                labels.GetValueOrDefault(sfn),
                sfnPis.Sum(row => row.Expenses),
                sfnPis.Sum(row => row.Fte),
                projectCounts.GetValueOrDefault(sfn),
                sfnPis));
        }

        // Rule 20x follows the employee; a 201/202/205 expense stays
        // unassociated when the summary row has no employee (AE rows never
        // do) or the employee owns no project of that SFN.
        var unassociated = (await connection.QueryAsync<UnassociatedExpenseDto>(Command(
            """
            SELECT
                e.[ExpenseId], e.[Source], e.[Project], e.[Fund], e.[FinancialDepartment], e.[OrgR],
                e.[EmployeeId], e.[EmployeeName], e.[ExpenseSfn], e.[Expenses], e.[Fte],
                CASE
                    WHEN e.[EmployeeId] IS NULL THEN N'NoEmployee'
                    WHEN NOT EXISTS
                    (
                        SELECT 1 FROM [data].[Projects] p
                        WHERE p.[UcpEmployeeId] = e.[EmployeeId] AND p.[Sfn] = e.[ExpenseSfn]
                    ) THEN N'NoProject'
                    ELSE N'NoRuleMatched'
                END AS [Reason]
            FROM [data].[ExpenseSummary] e
            WHERE e.[ExpenseSfn] IN ('201', '202', '205')
              AND e.[RuleExclusion] IS NULL
              AND NOT EXISTS (SELECT 1 FROM [data].[StagedAssociations] s WHERE s.[ExpenseId] = e.[ExpenseId])
            ORDER BY e.[ExpenseSfn], e.[EmployeeId], e.[ExpenseId]
            """, cancellationToken))).ToList();

        return new Rule20xReportDto(sfns, unassociated);
    }

    public async Task<Rule220ReportDto> GetRule220Async(CancellationToken cancellationToken)
    {
        await using var connection = await OpenAsync(cancellationToken);

        var projects = (await connection.QueryAsync<AssociatedProjectDto>(Command(
            ProjectInfoCte + """
            SELECT
                s.[AccessionNumber],
                p.[NifaProjectNumber],
                p.[Title],
                p.[ProjectDirector],
                CAST(NULL AS NVARCHAR(MAX)) AS [AeProjects],
                SUM(s.[Expenses]) AS [Expenses],
                SUM(s.[Fte]) AS [Fte]
            FROM [data].[StagedAssociations] s
            LEFT JOIN ProjectInfo p ON p.[AccessionNumber] = s.[AccessionNumber]
            WHERE s.[Rule] = N'220'
            GROUP BY s.[AccessionNumber], p.[NifaProjectNumber], p.[Title], p.[ProjectDirector]
            ORDER BY s.[AccessionNumber]
            """, cancellationToken))).ToList();

        // Every included SFN 220 expense that rule 220 did not take: AE rows
        // (no employee), payroll on an FTE line other than 241, employees
        // with no project or only excluded 204 projects. They all wait for
        // manual association.
        var unassociated = (await connection.QueryAsync<UnassociatedExpenseDto>(Command(
            """
            SELECT
                e.[ExpenseId], e.[Source], e.[Project], e.[Fund], e.[FinancialDepartment], e.[OrgR],
                e.[EmployeeId], e.[EmployeeName], e.[ExpenseSfn], e.[Expenses], e.[Fte],
                CASE
                    WHEN e.[EmployeeId] IS NULL THEN N'NoEmployee'
                    WHEN e.[FteSfn] IS NULL OR e.[FteSfn] <> '241' THEN N'NoFteLine'
                    WHEN NOT EXISTS (SELECT 1 FROM [data].[Projects] p WHERE p.[UcpEmployeeId] = e.[EmployeeId]) THEN N'NoProject'
                    WHEN NOT EXISTS
                    (
                        SELECT 1 FROM [data].[Projects] p
                        WHERE p.[UcpEmployeeId] = e.[EmployeeId]
                          AND NOT EXISTS (SELECT 1 FROM [data].[AutoAssociationExcludedProjects] x WHERE x.[AccessionNumber] = p.[AccessionNumber])
                    ) THEN N'ProjectExcluded'
                    ELSE N'NoRuleMatched'
                END AS [Reason]
            FROM [data].[ExpenseSummary] e
            WHERE e.[ExpenseSfn] = '220' AND NOT EXISTS (SELECT 1 FROM [data].[StagedAssociations] s WHERE s.[ExpenseId] = e.[ExpenseId])
            ORDER BY e.[EmployeeId], e.[ExpenseId]
            """, cancellationToken))).ToList();

        return new Rule220ReportDto(projects, unassociated);
    }

    private sealed record Rule20xPiRow(string Sfn, string EmployeeId, string? EmployeeName, int ProjectCount, decimal Expenses, decimal Fte);

    private sealed record SfnCountRow(string Sfn, int ProjectCount);

    private sealed record SfnLabelRow(string Sfn, string? Label);

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
