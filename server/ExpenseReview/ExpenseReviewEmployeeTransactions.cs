using System.Runtime.CompilerServices;
using Dapper;
using Server.Core.Data;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public sealed partial class ExpenseReviewService
{
    public async Task<ExpenseReviewEmployeeTransactionsResult> GetEmployeeTransactionsAsync(
        FiscalYearCycle cycle, ExpenseReviewEmployeeTransactionsRequest request, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildEmployeeTransactionsSql(request), EmployeeParameters(cycle, request),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken));
        if (!await reader.ReadSingleAsync<bool>()) return new(false, null);
        var employee = await reader.ReadSingleOrDefaultAsync<EmployeeDetailHeader>();
        if (employee == null) return new(true, null);
        var totals = await reader.ReadSingleAsync<ExpenseReviewTotalsRow>();
        var matching = await reader.ReadSingleAsync<ExpenseReviewTotalsRow>();
        var rows = (await reader.ReadAsync<DetailRow>()).Select(ToDetailDto).ToArray();
        return new(true, new(cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd,
            employee.EmployeeId, employee.EmployeeName, employee.ReportFte, request.Scope,
            totals.TotalCount, totals.TotalAmount, matching.TotalCount, matching.TotalAmount,
            request.Page, request.PageSize, (int)Math.Ceiling((double)matching.TotalCount / request.PageSize), rows));
    }

    public async Task WriteEmployeeTransactionsCsvAsync(FiscalYearCycle cycle,
        ExpenseReviewEmployeeTransactionsRequest request, ExpenseReviewEmployeeTransactionsResponse employee,
        Stream output, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildEmployeeTransactionsSql(request, export: true), EmployeeParameters(cycle, request),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken));
        if (!await reader.ReadSingleAsync<bool>())
            throw new ExpenseReviewEmployeeTransactionsUnavailableException(buildAvailable: false);
        var header = await reader.ReadSingleOrDefaultAsync<EmployeeDetailHeader>();
        if (header == null)
            throw new ExpenseReviewEmployeeTransactionsUnavailableException(buildAvailable: true);
        // Read the header in the same query as the export, rather than retaining a previous report FTE.
        await ExpenseReviewDetailCsvWriter.WriteEmployeeAsync(output, Rows(cancellationToken), cycle,
            employee with { EmployeeName = header.EmployeeName, ReportFte = header.ReportFte }, cancellationToken);

        async IAsyncEnumerable<ExpenseReviewTransactionDetailDto> Rows(
            [EnumeratorCancellation] CancellationToken token)
        {
            await foreach (var row in reader.ReadUnbufferedAsync<DetailRow>().WithCancellation(token))
                yield return ToDetailDto(row);
        }
    }

    private static object EmployeeParameters(FiscalYearCycle cycle, ExpenseReviewEmployeeTransactionsRequest request) => new
    {
        cycleStart = cycle.CycleStart.ToDateTime(TimeOnly.MinValue),
        cycleEnd = cycle.CycleEnd.ToDateTime(TimeOnly.MinValue),
        employeeId = request.EmployeeId,
        scope = request.Scope,
        search = request.Search,
        offset = (request.Page - 1) * request.PageSize,
        pageSize = request.PageSize,
    };

    public static string BuildEmployeeTransactionsSql(ExpenseReviewEmployeeTransactionsRequest request, bool export = false)
    {
        var sort = ExpenseReviewEmployeeTransactionsParser.SortColumns[request.SortBy];
        var direction = request.SortDescending ? "DESC" : "ASC";
        var orderBy = request.SortBy.Equals("id", StringComparison.OrdinalIgnoreCase)
            ? $"[LaborTransactionId] {direction}, [Id] ASC"
            : $"CASE WHEN [{sort}] IS NULL THEN 1 ELSE 0 END, [{sort}] {direction}, [Id] ASC";
        return $$"""
            IF NOT EXISTS (SELECT 1 FROM [data].[AutoAssociationBuilds]
                           WHERE [CycleStart] = @cycleStart AND [CycleEnd] = @cycleEnd)
            BEGIN
                SELECT CAST(0 AS BIT) AS [BuildAvailable];
                RETURN;
            END;
            SELECT CAST(1 AS BIT) AS [BuildAvailable];

            SELECT [EmployeeId], MAX([EmployeeName]) AS [EmployeeName], SUM([Fte]) AS [ReportFte]
            INTO #Employee
            FROM [data].[ExpenseSummary]
            WHERE [Source] = N'UCPath' AND [EmployeeId] = @employeeId
            GROUP BY [EmployeeId];
            SELECT * FROM #Employee;
            IF NOT EXISTS (SELECT 1 FROM #Employee) RETURN;

            WITH Unified AS ({{BuildUcPathTransactionsProjection(employee: true)}})
            SELECT m.[Id], m.[AeTransactionId], m.[LaborTransactionId], m.[AccountingPeriod], m.[AccountingPeriodSort], m.[Amount],
                u.[PayPeriodEndDate] AS [TransactionDate], u.[UcEarnEndDate], {{UcPathJournalIdSql("u")}} AS [TransactionId],
                u.[EmployeeId], u.[EmployeeName], u.[PositionNumber], u.[ErnCode], u.[ErnDescription],
                CASE u.[FringeBenefitSalaryCd] WHEN 'S' THEN N'Salary' WHEN 'F' THEN N'Fringe' END AS [SalaryFringe],
                u.[JobCode], u.[Hours], u.[CalculatedFte],
                CAST(NULL AS NVARCHAR(30)) AS [AccountingSequenceNumber], CAST(NULL AS BIGINT) AS [SequenceNumberSort],
                CAST(NULL AS NVARCHAR(1)) AS [JournalName], CAST(NULL AS NVARCHAR(1)) AS [LineDescription],
                CAST(NULL AS NVARCHAR(1)) AS [DocumentType], CAST(NULL AS NVARCHAR(1)) AS [JournalReference],
                u.[Entity], u.[FinancialDepartment], u.[Fund], u.[Account], u.[Project], u.[Purpose], u.[Program], u.[Activity],
                o.[OrgR], m.[Sfn] AS [ExpenseSfn], incl.[FteSfn], membership.[ReportIncluded],
                CASE WHEN membership.[ReportIncluded] = 1 AND incl.[ErnIncludeInReport] = 1
                     THEN u.[CalculatedFte] ELSE CAST(0 AS DECIMAL(9, 6)) END AS [ReportFteContribution],
                CASE WHEN COALESCE(m.[Included], 0) = 0 THEN N'Not in report: excluded transaction'
                     WHEN membership.[ReportIncluded] = 0 THEN N'Not in report: group nets to $0'
                     WHEN COALESCE(incl.[ErnIncludeInReport], 0) = 0 THEN N'FTE not counted: earnings code'
                     ELSE N'Report row' END AS [ReportStatus],
                (SELECT r.[Code], r.[Label], 1 AS [RowCount], COALESCE(m.[Amount], 0) AS [Amount]
                 FROM (VALUES {{ReasonValuesSql("m")}}) r([Code], [Label])
                 WHERE r.[Code] IS NOT NULL ORDER BY r.[Label], r.[Code] FOR JSON PATH) AS [ReasonsJson]
            INTO #Details
            FROM Unified m
            JOIN [data].[UcPathTransactions] u ON u.[LaborTransactionId] = m.[LaborTransactionId]
            JOIN [data].[v_TransactionInclusion] incl ON incl.[Source] = N'UCPath' AND incl.[LaborTransactionId] = u.[LaborTransactionId]
            LEFT JOIN [data].[v_TransactionOrgR] o ON o.[Source] = N'UCPath' AND o.[LaborTransactionId] = u.[LaborTransactionId]
            CROSS APPLY
            (
                -- Match exactly the BuildAutoAssociations summary grain, including nullable fields.
                -- Account/purpose/program do not split a summary. Individual $0 rows still belong.
                SELECT CAST(CASE WHEN m.[Included] = 1 AND EXISTS
                (
                    SELECT 1 FROM [data].[ExpenseSummary] e
                    WHERE e.[Source] = N'UCPath' AND e.[EmployeeId] = u.[EmployeeId]
                      AND {{SummaryMembershipSql()}}
                ) THEN 1 ELSE 0 END AS BIT) AS [ReportIncluded]
            ) membership
            WHERE @scope = 'all' OR membership.[ReportIncluded] = 1;

            {{(export ? "" : "SELECT COUNT(*) AS [TotalCount], COALESCE(SUM([Amount]), 0) AS [TotalAmount] FROM #Details;")}}
            {{DetailSearchSql(employee: true)}}
            {{(export ? "" : "SELECT COUNT(*) AS [TotalCount], COALESCE(SUM([Amount]), 0) AS [TotalAmount] FROM #Details;")}}
            SELECT * FROM #Details ORDER BY {{orderBy}}
            {{(export ? "" : "OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY")}};
            """;
    }

    private static string SummaryMembershipSql()
    {
        var fields = new (string Summary, string Transaction)[]
        {
            ("OrgR", "o.[OrgR]"), ("Entity", "u.[Entity]"), ("Project", "u.[Project]"),
            ("Activity", "u.[Activity]"), ("Fund", "u.[Fund]"), ("FinancialDepartment", "u.[FinancialDepartment]"),
            ("EmployeeName", "u.[EmployeeName]"), ("JobCode", "u.[JobCode]"),
            ("ExpenseSfn", "m.[Sfn]"), ("FteSfn", "incl.[FteSfn]"),
        };
        return string.Join("\n AND ", fields.Select(field =>
            $"(e.[{field.Summary}] = {field.Transaction} OR (e.[{field.Summary}] IS NULL AND {field.Transaction} IS NULL))"));
    }

    private sealed record EmployeeDetailHeader(string EmployeeId, string? EmployeeName, decimal ReportFte);
}
