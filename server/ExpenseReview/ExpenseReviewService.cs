using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public sealed class ExpenseReviewService(
    DataDbContext dataDbContext,
    IConfiguration configuration) : IExpenseReviewService
{
    private static readonly IReadOnlyDictionary<string, string> SortExpressions =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["accountingPeriod"] = "[AccountingPeriodSort]",
            ["entity"] = "[EntityCode]",
            ["financialDept"] = "[FinancialDeptCode]",
            ["fund"] = "[FundCode]",
            ["account"] = "[AccountCode]",
            ["aeProject"] = "[AeProjectCode]",
            ["purpose"] = "[PurposeCode]",
            ["program"] = "[ProgramCode]",
            ["activity"] = "[ActivityCode]",
            ["sfn"] = "[Sfn]",
            ["source"] = "[Source]",
            ["amount"] = "[Amount]",
            ["included"] = "[Included]",
        };

    private static readonly IReadOnlyList<string> ChartStringSortExpressions =
    [
        "[EntityCode]",
        "[FundCode]",
        "[FinancialDeptCode]",
        "[AccountCode]",
        "[PurposeCode]",
        "[ProgramCode]",
        "[AeProjectCode]",
        "[ActivityCode]",
    ];

    public async Task<ExpenseReviewTransactionsResponse> GetTransactionsAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var parameters = CreateParameters(cycle, request);
        var sql = BuildTransactionsSql(request);

        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            sql,
            parameters,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        var counts = await reader.ReadSingleAsync<ExpenseReviewCountsDto>();
        var totalCount = await reader.ReadSingleAsync<int>();
        var rows = (await reader.ReadAsync<ExpenseReviewTransactionRow>()).ToList();
        var reasons = (await reader.ReadAsync<ExpenseReviewReasonRow>()).ToList();

        return new ExpenseReviewTransactionsResponse(
            cycle.FiscalYear,
            cycle.CycleStart,
            cycle.CycleEnd,
            counts,
            totalCount,
            request.Page,
            request.PageSize,
            totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)request.PageSize),
            ToDtos(rows, reasons));
    }

    public async Task<ExpenseReviewFilterOptionsResponse> GetFilterOptionsAsync(
        FiscalYearCycle cycle,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var rows = (await connection.QueryAsync<ExpenseReviewFilterOptionRow>(new CommandDefinition(
            FilterOptionsSql,
            CycleParameters(cycle),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken))).ToList();

        IReadOnlyList<ExpenseReviewFilterOptionDto> Options(string filter) =>
            rows.Where(row => row.Filter == filter)
                .Select(row => new ExpenseReviewFilterOptionDto(row.Value, row.Label))
                .ToList();

        return new ExpenseReviewFilterOptionsResponse(
            Options("entity"),
            Options("financialDept"),
            Options("fund"),
            Options("account"),
            Options("aeProject"),
            Options("accountingPeriod"),
            Options("purpose"),
            Options("program"),
            Options("activity"),
            Options("sfn"),
            Options("source"),
            Options("exclusionReason"));
    }

    public async Task WriteTransactionsCsvAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        Stream output,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var parameters = CreateParameters(cycle, request);

        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildTransactionsExportSql(request),
            parameters,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        var rows = (await reader.ReadAsync<ExpenseReviewTransactionRow>()).ToList();
        var reasons = (await reader.ReadAsync<ExpenseReviewReasonRow>()).ToList();

        await ExpenseReviewCsvWriter.WriteAsync(
            output,
            ToAsyncEnumerable(ToDtos(rows, reasons)),
            request.DisplayByPeriod,
            cancellationToken);
    }

    public static string BuildTransactionsSql(ExpenseReviewTransactionsRequest request)
    {
        var includeClause = BuildIncludeClause(request.IncludeState, "g");
        var orderByClause = BuildOrderByClause(request, "g");

        return $$"""
            {{BuildGroupedTempTablesSql(request)}}

            SELECT
                COUNT(1) AS [All],
                COALESCE(SUM(CASE WHEN [Included] = 1 THEN 1 ELSE 0 END), 0) AS [Included],
                COALESCE(SUM(CASE WHEN [Included] = 0 THEN 1 ELSE 0 END), 0) AS [Excluded]
            FROM #Grouped;

            SELECT COUNT(1)
            FROM #Grouped g
            WHERE {{includeClause}};

            SELECT [Id]
            INTO #PagedGroupIds
            FROM #Grouped g
            WHERE {{includeClause}}
            ORDER BY
                {{orderByClause}}
            OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY;

            SELECT
                {{GroupedSelectColumns}}
            FROM #Grouped g
            WHERE g.[Id] IN (SELECT [Id] FROM #PagedGroupIds)
            ORDER BY
                {{orderByClause}};

            SELECT
                r.[GroupId],
                r.[Code],
                r.[Label],
                r.[RowCount],
                r.[Amount]
            FROM #AggregatedReasons r
            INNER JOIN #PagedGroupIds p ON p.[Id] = r.[GroupId]
            ORDER BY r.[GroupId], r.[Label], r.[Code];
            """;
    }

    public static string BuildTransactionsExportSql(ExpenseReviewTransactionsRequest request)
    {
        var includeClause = BuildIncludeClause(request.IncludeState, "g");
        var orderByClause = BuildOrderByClause(request, "g");

        return $$"""
            {{BuildGroupedTempTablesSql(request)}}

            SELECT
                {{GroupedSelectColumns}}
            FROM #Grouped g
            WHERE {{includeClause}}
            ORDER BY
                {{orderByClause}};

            SELECT
                r.[GroupId],
                r.[Code],
                r.[Label],
                r.[RowCount],
                r.[Amount]
            FROM #AggregatedReasons r
            INNER JOIN #Grouped g ON g.[Id] = r.[GroupId]
            WHERE {{includeClause}}
            ORDER BY r.[GroupId], r.[Label], r.[Code];
            """;
    }

    private static string BuildGroupedTempTablesSql(ExpenseReviewTransactionsRequest request)
    {
        var filters = request.Filters;
        var filterClause = BuildFilterClause(filters, "u");
        var exclusionReasonClause = BuildExclusionReasonFilterClause(filters, "t");
        var periodSelectColumns = request.DisplayByPeriod
            ? "t.[AccountingPeriod],\n                t.[AccountingPeriodSort],"
            : "CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod],\n                CAST(NULL AS DATE) AS [AccountingPeriodSort],";
        var periodGroupByColumns = request.DisplayByPeriod
            ? ",\n                t.[AccountingPeriod],\n                t.[AccountingPeriodSort]"
            : string.Empty;

        return $$"""
            {{UnifiedTransactionsCte}}
            SELECT *
            INTO #CycleTransactions
            FROM Unified u
            WHERE {{filterClause}};

            {{BuildReasonRowsSql("#CycleTransactions", "#CycleReasons", request.DisplayByPeriod)}}

            SELECT t.*
            INTO #FilteredTransactions
            FROM #CycleTransactions t
            WHERE {{exclusionReasonClause}};

            {{BuildReasonRowsSql("#FilteredTransactions", "#FilteredReasons", request.DisplayByPeriod)}}

            SELECT
                {{GroupIdExpression("t", request.DisplayByPeriod)}} AS [Id],
                t.[Source],
                {{periodSelectColumns}}
                t.[EntityCode],
                MAX(NULLIF(t.[EntityName], N'')) AS [EntityName],
                t.[FinancialDeptCode],
                MAX(NULLIF(t.[FinancialDeptName], N'')) AS [FinancialDeptName],
                t.[FundCode],
                MAX(NULLIF(t.[FundName], N'')) AS [FundName],
                t.[AccountCode],
                MAX(NULLIF(t.[AccountName], N'')) AS [AccountName],
                t.[AeProjectCode],
                MAX(NULLIF(t.[AeProjectName], N'')) AS [AeProjectName],
                t.[PurposeCode],
                MAX(NULLIF(t.[PurposeName], N'')) AS [PurposeName],
                t.[ProgramCode],
                MAX(NULLIF(t.[ProgramName], N'')) AS [ProgramName],
                t.[ActivityCode],
                MAX(NULLIF(t.[ActivityName], N'')) AS [ActivityName],
                MAX(t.[Sfn]) AS [Sfn],
                MAX(t.[SfnLabel]) AS [SfnLabel],
                SUM(t.[Amount]) AS [Amount],
                t.[Included]
            INTO #Grouped
            FROM #FilteredTransactions t
            GROUP BY
                t.[Source],
                t.[Included],
                t.[EntityCode],
                t.[FinancialDeptCode],
                t.[FundCode],
                t.[AccountCode],
                t.[AeProjectCode],
                t.[PurposeCode],
                t.[ProgramCode],
                t.[ActivityCode]{{periodGroupByColumns}};

            SELECT
                r.[GroupId],
                r.[Code],
                r.[Label],
                COUNT(1) AS [RowCount],
                SUM(COALESCE(r.[Amount], 0)) AS [Amount]
            INTO #AggregatedReasons
            FROM #FilteredReasons r
            GROUP BY r.[GroupId], r.[Code], r.[Label];
            """;
    }

    private static string BuildReasonRowsSql(string source, string destination, bool displayByPeriod) =>
        $$"""
            SELECT
                t.[Id] AS [TransactionId],
                {{GroupIdExpression("t", displayByPeriod)}} AS [GroupId],
                reason.[Code],
                reason.[Label],
                t.[Amount]
            INTO {{destination}}
            FROM {{source}} t
            CROSS APPLY
            (
                VALUES
                    {{ReasonValuesSql("t")}}
            ) reason([Code], [Label])
            WHERE reason.[Code] IS NOT NULL;
            """;

    private static string BuildIncludeClause(ExpenseReviewIncludeState includeState, string alias)
    {
        var prefix = string.IsNullOrWhiteSpace(alias) ? string.Empty : $"{alias}.";

        return includeState switch
        {
            ExpenseReviewIncludeState.Included => $"{prefix}[Included] = 1",
            ExpenseReviewIncludeState.Excluded => $"{prefix}[Included] = 0",
            _ => "1 = 1",
        };
    }

    private static string BuildOrderByClause(ExpenseReviewTransactionsRequest request, string alias)
    {
        var sortExpression = Qualify(SortExpressions[request.SortBy], alias);
        var sortDirection = request.SortDescending ? "DESC" : "ASC";
        var orderByExpressions = new List<string>
        {
            $"CASE WHEN {sortExpression} IS NULL THEN 1 ELSE 0 END",
            $"{sortExpression} {sortDirection}",
        };

        IEnumerable<string> periodTieBreakers = request.DisplayByPeriod
            ? ["[AccountingPeriodSort]"]
            : [];
        var tieBreakers = ChartStringSortExpressions
            .Prepend("[Source]")
            .Concat(periodTieBreakers);
        foreach (var tieBreaker in tieBreakers.Select(expression => Qualify(expression, alias)))
        {
            if (!string.Equals(sortExpression, tieBreaker, StringComparison.OrdinalIgnoreCase))
            {
                orderByExpressions.Add(tieBreaker);
            }
        }
        orderByExpressions.Add(Qualify("[Id]", alias));

        return string.Join(",\n                ", orderByExpressions);
    }

    private static string Qualify(string expression, string alias)
    {
        if (string.IsNullOrWhiteSpace(alias))
        {
            return expression;
        }

        return expression.StartsWith("[", StringComparison.Ordinal)
            ? $"{alias}.{expression}"
            : expression;
    }

    public static string FilterOptionsSql => $$"""
        {{UnifiedTransactionsCte}},
        ReasonOptions AS
        (
            SELECT DISTINCT
                reason.[Code],
                reason.[Label]
            FROM Unified u
            CROSS APPLY
            (
                VALUES
                    {{ReasonValuesSql("u")}}
            ) reason([Code], [Label])
            WHERE reason.[Code] IS NOT NULL
        )
        SELECT [Filter], [Value], [Label]
        FROM
        (
        SELECT
            CAST('entity' AS NVARCHAR(30)) AS [Filter],
            [EntityCode] AS [Value],
            {{CodeNameLabelExpression("[EntityCode]", "MAX(NULLIF([EntityName], N''))")}} AS [Label],
            CAST([EntityCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [EntityCode] IS NOT NULL
        GROUP BY [EntityCode]
        UNION ALL
        SELECT
            CAST('financialDept' AS NVARCHAR(30)) AS [Filter],
            [FinancialDeptCode] AS [Value],
            {{CodeNameLabelExpression("[FinancialDeptCode]", "MAX(NULLIF([FinancialDeptName], N''))")}} AS [Label],
            CAST([FinancialDeptCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [FinancialDeptCode] IS NOT NULL
        GROUP BY [FinancialDeptCode]
        UNION ALL
        SELECT
            CAST('fund' AS NVARCHAR(30)) AS [Filter],
            [FundCode] AS [Value],
            {{CodeNameLabelExpression("[FundCode]", "MAX(NULLIF([FundName], N''))")}} AS [Label],
            CAST([FundCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [FundCode] IS NOT NULL
        GROUP BY [FundCode]
        UNION ALL
        SELECT
            CAST('account' AS NVARCHAR(30)) AS [Filter],
            [AccountCode] AS [Value],
            {{CodeNameLabelExpression("[AccountCode]", "MAX(NULLIF([AccountName], N''))")}} AS [Label],
            CAST([AccountCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [AccountCode] IS NOT NULL
        GROUP BY [AccountCode]
        UNION ALL
        SELECT
            CAST('aeProject' AS NVARCHAR(30)) AS [Filter],
            [AeProjectCode] AS [Value],
            {{CodeNameLabelExpression("[AeProjectCode]", "MAX(NULLIF([AeProjectName], N''))")}} AS [Label],
            CAST([AeProjectCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [AeProjectCode] IS NOT NULL
        GROUP BY [AeProjectCode]
        UNION ALL
        SELECT
            CAST('accountingPeriod' AS NVARCHAR(30)) AS [Filter],
            [AccountingPeriod] AS [Value],
            [AccountingPeriod] AS [Label],
            CONVERT(NVARCHAR(30), MIN([AccountingPeriodSort]), 126) AS [SortKey]
        FROM Unified
        WHERE [AccountingPeriod] IS NOT NULL
        GROUP BY [AccountingPeriod]
        UNION ALL
        SELECT
            CAST('purpose' AS NVARCHAR(30)) AS [Filter],
            [PurposeCode] AS [Value],
            {{CodeNameLabelExpression("[PurposeCode]", "MAX(NULLIF([PurposeName], N''))")}} AS [Label],
            CAST([PurposeCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [PurposeCode] IS NOT NULL
        GROUP BY [PurposeCode]
        UNION ALL
        SELECT
            CAST('program' AS NVARCHAR(30)) AS [Filter],
            [ProgramCode] AS [Value],
            {{CodeNameLabelExpression("[ProgramCode]", "MAX(NULLIF([ProgramName], N''))")}} AS [Label],
            CAST([ProgramCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [ProgramCode] IS NOT NULL
        GROUP BY [ProgramCode]
        UNION ALL
        SELECT
            CAST('activity' AS NVARCHAR(30)) AS [Filter],
            [ActivityCode] AS [Value],
            {{CodeNameLabelExpression("[ActivityCode]", "MAX(NULLIF([ActivityName], N''))")}} AS [Label],
            CAST([ActivityCode] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [ActivityCode] IS NOT NULL
        GROUP BY [ActivityCode]
        UNION ALL
        SELECT
            CAST('sfn' AS NVARCHAR(30)) AS [Filter],
            [Sfn] AS [Value],
            {{CodeNameLabelExpression("[Sfn]", "MAX(NULLIF([SfnLabel], N''))")}} AS [Label],
            CAST([Sfn] AS NVARCHAR(500)) AS [SortKey]
        FROM Unified
        WHERE [Sfn] IS NOT NULL
        GROUP BY [Sfn]
        UNION ALL
        SELECT DISTINCT
            CAST('source' AS NVARCHAR(30)) AS [Filter],
            [Source] AS [Value],
            CASE [Source] WHEN N'AE' THEN N'Aggie Enterprise' ELSE N'UCPath' END AS [Label],
            [Source] AS [SortKey]
        FROM Unified
        UNION ALL
        SELECT
            CAST('exclusionReason' AS NVARCHAR(30)) AS [Filter],
            [Code] AS [Value],
            [Label],
            [Label] AS [SortKey]
        FROM ReasonOptions
        ) options
        ORDER BY [Filter], [SortKey], [Value], [Label];
        """;

    public const string UnifiedTransactionsCte = """
        WITH Unified AS
        (
            SELECT
                CAST(CONCAT('AE:', a.[Id]) AS NVARCHAR(160)) AS [Id],
                CAST('AE' AS NVARCHAR(3)) AS [Source],
                a.[Entity] AS [EntityCode],
                a.[EntityDescription] AS [EntityName],
                a.[FinancialDepartment] AS [FinancialDeptCode],
                a.[FinancialDepartmentDescription] AS [FinancialDeptName],
                a.[Fund] AS [FundCode],
                a.[FundDescription] AS [FundName],
                a.[Account] AS [AccountCode],
                a.[AccountDescription] AS [AccountName],
                a.[Project] AS [AeProjectCode],
                a.[ProjectDescription] AS [AeProjectName],
                a.[Purpose] AS [PurposeCode],
                a.[PurposeDescription] AS [PurposeName],
                a.[Program] AS [ProgramCode],
                a.[ProgramDescription] AS [ProgramName],
                a.[Activity] AS [ActivityCode],
                a.[ActivityDescription] AS [ActivityName],
                a.[PeriodName] AS [AccountingPeriod],
                TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) AS [AccountingPeriodSort],
                fundClass.[Sfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                a.[Amount] AS [Amount],
                a.[ExcludedByDate],
                a.[AccountInUcPath],
                CAST(NULL AS BIT) AS [AccountNotInAE],
                financialDeptClass.[IncludeInReport] AS [FinancialDeptIncludeInReport],
                fundClass.[IncludeInReport] AS [FundIncludeInReport],
                accountClass.[IncludeInReport] AS [AccountIncludeInReport],
                activityClass.[IncludeInReport] AS [ActivityIncludeInReport],
                purposeClass.[IncludeInReport] AS [PurposeIncludeInReport],
                CASE
                    WHEN a.[ExcludedByDate] = 0
                     AND a.[AccountInUcPath] = 0
                     -- TODO: Seek stakeholder review on this fail-closed null/missing classification behavior.
                     AND COALESCE(financialDeptClass.[IncludeInReport], 0) = 1
                     AND COALESCE(fundClass.[IncludeInReport], 0) = 1
                     AND COALESCE(accountClass.[IncludeInReport], 0) = 1
                     AND COALESCE(activityClass.[IncludeInReport], 0) = 1
                     AND (a.[Fund] = '13U02' OR COALESCE(purposeClass.[IncludeInReport], 0) = 1)
                    THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS [Included]
            FROM [data].[AETransactions] a
            LEFT JOIN [data].[SegmentClassifications] financialDeptClass
                ON financialDeptClass.[SegmentType] = 'FinancialDepartment'
               AND financialDeptClass.[Code] = a.[FinancialDepartment]
            LEFT JOIN [data].[SegmentClassifications] fundClass
                ON fundClass.[SegmentType] = 'Fund'
               AND fundClass.[Code] = a.[Fund]
            LEFT JOIN [data].[SegmentClassifications] accountClass
                ON accountClass.[SegmentType] = 'Account'
               AND accountClass.[Code] = a.[Account]
            LEFT JOIN [data].[SegmentClassifications] activityClass
                ON activityClass.[SegmentType] = 'Activity'
               AND activityClass.[Code] = a.[Activity]
            LEFT JOIN [data].[SegmentClassifications] purposeClass
                ON purposeClass.[SegmentType] = 'Purpose'
               AND purposeClass.[Code] = a.[Purpose]
            LEFT JOIN [data].[Sfns] sfn
                ON sfn.[Sfn] = fundClass.[Sfn]
            WHERE TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) BETWEEN @cycleStart AND @cycleEnd

            UNION ALL

            SELECT
                CAST(CONCAT('UCP:', u.[LaborTransactionId]) AS NVARCHAR(160)) AS [Id],
                CAST('UCP' AS NVARCHAR(3)) AS [Source],
                u.[Entity] AS [EntityCode],
                COALESCE(NULLIF(entitySegment.[ValueDesc], ''), NULLIF(entitySegment.[Description], '')) AS [EntityName],
                u.[FinancialDepartment] AS [FinancialDeptCode],
                COALESCE(NULLIF(financialDeptSegment.[ValueDesc], ''), NULLIF(financialDeptSegment.[Description], '')) AS [FinancialDeptName],
                u.[Fund] AS [FundCode],
                COALESCE(NULLIF(fundSegment.[ValueDesc], ''), NULLIF(fundSegment.[Description], '')) AS [FundName],
                u.[Account] AS [AccountCode],
                COALESCE(NULLIF(accountSegment.[ValueDesc], ''), NULLIF(accountSegment.[Description], '')) AS [AccountName],
                u.[Project] AS [AeProjectCode],
                COALESCE(NULLIF(projectSegment.[ValueDesc], ''), NULLIF(projectSegment.[Description], '')) AS [AeProjectName],
                u.[Purpose] AS [PurposeCode],
                COALESCE(NULLIF(purposeSegment.[ValueDesc], ''), NULLIF(purposeSegment.[Description], '')) AS [PurposeName],
                u.[Program] AS [ProgramCode],
                COALESCE(NULLIF(programSegment.[ValueDesc], ''), NULLIF(programSegment.[Description], '')) AS [ProgramName],
                u.[Activity] AS [ActivityCode],
                COALESCE(NULLIF(activitySegment.[ValueDesc], ''), NULLIF(activitySegment.[Description], '')) AS [ActivityName],
                CASE
                    WHEN ucPeriod.[PeriodStart] IS NULL THEN NULL
                    ELSE FORMAT(ucPeriod.[PeriodStart], 'MMM-yy', 'en-US')
                END AS [AccountingPeriod],
                ucPeriod.[PeriodStart] AS [AccountingPeriodSort],
                fundClass.[Sfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                u.[Amount] AS [Amount],
                u.[ExcludedByDate],
                CAST(NULL AS BIT) AS [AccountInUcPath],
                u.[AccountNotInAE],
                financialDeptClass.[IncludeInReport] AS [FinancialDeptIncludeInReport],
                fundClass.[IncludeInReport] AS [FundIncludeInReport],
                accountClass.[IncludeInReport] AS [AccountIncludeInReport],
                activityClass.[IncludeInReport] AS [ActivityIncludeInReport],
                purposeClass.[IncludeInReport] AS [PurposeIncludeInReport],
                CASE
                    WHEN u.[ExcludedByDate] = 0
                     AND u.[AccountNotInAE] = 0
                     -- TODO: Seek stakeholder review on this fail-closed null/missing classification behavior.
                     AND COALESCE(financialDeptClass.[IncludeInReport], 0) = 1
                     AND COALESCE(fundClass.[IncludeInReport], 0) = 1
                     AND COALESCE(accountClass.[IncludeInReport], 0) = 1
                     AND COALESCE(activityClass.[IncludeInReport], 0) = 1
                     AND (u.[Fund] = '13U02' OR COALESCE(purposeClass.[IncludeInReport], 0) = 1)
                    THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS [Included]
            FROM [data].[UcPathTransactions] u
            CROSS APPLY
            (
                SELECT TRY_CONVERT(INT, NULLIF(u.[Period], '')) AS [PeriodNumber]
            ) periodValue
            OUTER APPLY
            (
                SELECT CASE
                    WHEN periodValue.[PeriodNumber] BETWEEN 1 AND 12
                    THEN DATEFROMPARTS(
                        CASE
                            WHEN periodValue.[PeriodNumber] BETWEEN 1 AND 6 THEN u.[FiscalYear]
                            ELSE u.[FiscalYear] - 1
                        END,
                        ((periodValue.[PeriodNumber] + 5) % 12) + 1,
                        1)
                    ELSE NULL
                END AS [PeriodStart]
            ) ucPeriod
            LEFT JOIN [data].[ChartSegments] entitySegment
                ON entitySegment.[SegmentName] = 'Entity'
               AND entitySegment.[Code] = u.[Entity]
            LEFT JOIN [data].[ChartSegments] financialDeptSegment
                ON financialDeptSegment.[SegmentName] = 'FinancialDepartment'
               AND financialDeptSegment.[Code] = u.[FinancialDepartment]
            LEFT JOIN [data].[ChartSegments] fundSegment
                ON fundSegment.[SegmentName] = 'Fund'
               AND fundSegment.[Code] = u.[Fund]
            LEFT JOIN [data].[ChartSegments] accountSegment
                ON accountSegment.[SegmentName] = 'Account'
               AND accountSegment.[Code] = u.[Account]
            LEFT JOIN [data].[ChartSegments] projectSegment
                ON projectSegment.[SegmentName] = 'Project'
               AND projectSegment.[Code] = u.[Project]
            LEFT JOIN [data].[ChartSegments] purposeSegment
                ON purposeSegment.[SegmentName] = 'Purpose'
               AND purposeSegment.[Code] = u.[Purpose]
            LEFT JOIN [data].[ChartSegments] programSegment
                ON programSegment.[SegmentName] = 'Program'
               AND programSegment.[Code] = u.[Program]
            LEFT JOIN [data].[ChartSegments] activitySegment
                ON activitySegment.[SegmentName] = 'Activity'
               AND activitySegment.[Code] = u.[Activity]
            LEFT JOIN [data].[SegmentClassifications] financialDeptClass
                ON financialDeptClass.[SegmentType] = 'FinancialDepartment'
               AND financialDeptClass.[Code] = u.[FinancialDepartment]
            LEFT JOIN [data].[SegmentClassifications] fundClass
                ON fundClass.[SegmentType] = 'Fund'
               AND fundClass.[Code] = u.[Fund]
            LEFT JOIN [data].[SegmentClassifications] accountClass
                ON accountClass.[SegmentType] = 'Account'
               AND accountClass.[Code] = u.[Account]
            LEFT JOIN [data].[SegmentClassifications] activityClass
                ON activityClass.[SegmentType] = 'Activity'
               AND activityClass.[Code] = u.[Activity]
            LEFT JOIN [data].[SegmentClassifications] purposeClass
                ON purposeClass.[SegmentType] = 'Purpose'
               AND purposeClass.[Code] = u.[Purpose]
            LEFT JOIN [data].[Sfns] sfn
                ON sfn.[Sfn] = fundClass.[Sfn]
            WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
        )
        """;

    private const string GroupedSelectColumns = """
        [Id],
        [Source],
        [AccountingPeriod],
        [AccountingPeriodSort],
        [EntityCode],
        [EntityName],
        [FinancialDeptCode],
        [FinancialDeptName],
        [FundCode],
        [FundName],
        [AccountCode],
        [AccountName],
        [AeProjectCode],
        [AeProjectName],
        [PurposeCode],
        [PurposeName],
        [ProgramCode],
        [ProgramName],
        [ActivityCode],
        [ActivityName],
        [Sfn],
        [SfnLabel],
        [Amount],
        [Included]
        """;

    private SqlConnection CreateConnection()
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        return new SqlConnection(connectionString);
    }

    private static IReadOnlyList<ExpenseReviewTransactionDto> ToDtos(
        IReadOnlyList<ExpenseReviewTransactionRow> rows,
        IReadOnlyList<ExpenseReviewReasonRow> reasonRows)
    {
        var reasonsByGroup = reasonRows.ToLookup(reason => reason.GroupId);

        return rows
            .Select(row => new ExpenseReviewTransactionDto(
                row.Id,
                row.Source,
                new ExpenseReviewCodeNameDto(row.EntityCode, row.EntityName),
                new ExpenseReviewCodeNameDto(row.FinancialDeptCode, row.FinancialDeptName),
                new ExpenseReviewCodeNameDto(row.FundCode, row.FundName),
                new ExpenseReviewCodeNameDto(row.AccountCode, row.AccountName),
                new ExpenseReviewCodeNameDto(row.AeProjectCode, row.AeProjectName),
                row.AccountingPeriod,
                new ExpenseReviewCodeNameDto(row.PurposeCode, row.PurposeName),
                new ExpenseReviewCodeNameDto(row.ProgramCode, row.ProgramName),
                new ExpenseReviewCodeNameDto(row.ActivityCode, row.ActivityName),
                row.Sfn,
                row.SfnLabel,
                row.Amount,
                row.Included,
                reasonsByGroup[row.Id]
                    .Select(reason => new ExpenseReviewExclusionReasonDto(
                        reason.Code,
                        reason.Label,
                        reason.RowCount,
                        reason.Amount))
                    .ToList()))
            .ToList();
    }

    private static async IAsyncEnumerable<T> ToAsyncEnumerable<T>(IEnumerable<T> rows)
    {
        foreach (var row in rows)
        {
            await Task.Yield();
            yield return row;
        }
    }

    private static DynamicParameters CreateParameters(FiscalYearCycle cycle, ExpenseReviewTransactionsRequest request)
    {
        var parameters = CycleParameters(cycle);
        parameters.Add("offset", (request.Page - 1) * request.PageSize);
        parameters.Add("pageSize", request.PageSize);

        AddList("entity", request.Filters.Entity);
        AddList("financialDept", request.Filters.FinancialDept);
        AddList("fund", request.Filters.Fund);
        AddList("account", request.Filters.Account);
        AddList("aeProject", request.Filters.AeProject);
        AddList("accountingPeriod", request.Filters.AccountingPeriod);
        AddList("purpose", request.Filters.Purpose);
        AddList("program", request.Filters.Program);
        AddList("activity", request.Filters.Activity);
        AddList("sfn", request.Filters.Sfn);
        AddList("source", request.Filters.Source);
        AddList("exclusionReason", request.Filters.ExclusionReason);

        return parameters;

        void AddList(string name, IReadOnlyList<string> values)
        {
            if (values.Count > 0)
            {
                parameters.Add(name, values);
            }
        }
    }

    private static DynamicParameters CycleParameters(FiscalYearCycle cycle)
    {
        var parameters = new DynamicParameters();
        parameters.Add("cycleStart", cycle.CycleStart.ToDateTime(TimeOnly.MinValue));
        parameters.Add("cycleEnd", cycle.CycleEnd.ToDateTime(TimeOnly.MinValue));
        return parameters;
    }

    private static string BuildFilterClause(ExpenseReviewFilters filters, string alias)
    {
        var clauses = new List<string>();

        AddListFilter(filters.Entity, $"{alias}.[EntityCode] IN @entity");
        AddListFilter(filters.FinancialDept, $"{alias}.[FinancialDeptCode] IN @financialDept");
        AddListFilter(filters.Fund, $"{alias}.[FundCode] IN @fund");
        AddListFilter(filters.Account, $"{alias}.[AccountCode] IN @account");
        AddListFilter(filters.AeProject, $"{alias}.[AeProjectCode] IN @aeProject");
        AddListFilter(filters.AccountingPeriod, $"{alias}.[AccountingPeriod] IN @accountingPeriod");
        AddListFilter(filters.Purpose, $"{alias}.[PurposeCode] IN @purpose");
        AddListFilter(filters.Program, $"{alias}.[ProgramCode] IN @program");
        AddListFilter(filters.Activity, $"{alias}.[ActivityCode] IN @activity");
        AddListFilter(filters.Sfn, $"{alias}.[Sfn] IN @sfn");
        AddListFilter(filters.Source, $"{alias}.[Source] IN @source");

        return clauses.Count == 0 ? "1 = 1" : string.Join("\n              AND ", clauses);

        void AddListFilter(IReadOnlyList<string> values, string clause)
        {
            if (values.Count > 0)
            {
                clauses.Add(clause);
            }
        }
    }

    private static string BuildExclusionReasonFilterClause(ExpenseReviewFilters filters, string alias)
    {
        if (filters.ExclusionReason.Count == 0)
        {
            return "1 = 1";
        }

        return $"""
            EXISTS
            (
                SELECT 1
                FROM #CycleReasons selectedReason
                WHERE selectedReason.[TransactionId] = {alias}.[Id]
                  AND selectedReason.[Code] IN @exclusionReason
            )
            """;
    }

    private static string GroupIdExpression(string alias, bool displayByPeriod)
    {
        var prefix = string.IsNullOrWhiteSpace(alias) ? string.Empty : $"{alias}.";
        var periodKey = displayByPeriod
            ? $",\n                N'|accountingPeriod=', COALESCE({prefix}[AccountingPeriod], N'<NULL>')"
            : string.Empty;

        return $"""
            CONVERT(NVARCHAR(64), HASHBYTES('SHA2_256', CONCAT(
                N'source=', COALESCE({prefix}[Source], N'<NULL>'),
                N'|entity=', COALESCE({prefix}[EntityCode], N'<NULL>'),
                N'|fund=', COALESCE({prefix}[FundCode], N'<NULL>'),
                N'|financialDept=', COALESCE({prefix}[FinancialDeptCode], N'<NULL>'),
                N'|account=', COALESCE({prefix}[AccountCode], N'<NULL>'),
                N'|purpose=', COALESCE({prefix}[PurposeCode], N'<NULL>'),
                N'|program=', COALESCE({prefix}[ProgramCode], N'<NULL>'),
                N'|project=', COALESCE({prefix}[AeProjectCode], N'<NULL>'),
                N'|activity=', COALESCE({prefix}[ActivityCode], N'<NULL>'),
                N'|included=', CONVERT(NVARCHAR(1), COALESCE({prefix}[Included], 0)){periodKey}
            )), 2)
            """;
    }

    private static string CodeNameLabelExpression(string codeExpression, string nameExpression) =>
        $"CONCAT({codeExpression}, CASE WHEN {nameExpression} IS NULL THEN N'' ELSE CONCAT(N' - ', {nameExpression}) END)";

    private static string ReasonValuesSql(string alias) =>
        $$"""
                    (CASE WHEN {{alias}}.[ExcludedByDate] = 1 THEN CAST(N'excludedByDate' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ExcludedByDate] = 1 THEN CAST(N'Date excluded' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Source] = N'AE' AND {{alias}}.[AccountInUcPath] = 1 THEN CAST(CONCAT(N'aeAccountInUcPath:', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)')) AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Source] = N'AE' AND {{alias}}.[AccountInUcPath] = 1 THEN CAST(CONCAT(N'AE account ', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N' also in UCPath') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[AccountNotInAE] = 1 THEN CAST(CONCAT(N'ucPathAccountNotInAE:', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)')) AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[AccountNotInAE] = 1 THEN CAST(CONCAT(N'UCPath account ', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N' missing from AE chart') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN CAST(CONCAT(N'financialDept:', COALESCE(NULLIF({{alias}}.[FinancialDeptCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN CAST(CONCAT(N'Financial Dept ', COALESCE(NULLIF({{alias}}.[FinancialDeptCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN CAST(CONCAT(N'financialDept:', COALESCE(NULLIF({{alias}}.[FinancialDeptCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN CAST(CONCAT(N'Financial Dept ', COALESCE(NULLIF({{alias}}.[FinancialDeptCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN CAST(CONCAT(N'fund:', COALESCE(NULLIF({{alias}}.[FundCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN CAST(CONCAT(N'Fund ', COALESCE(NULLIF({{alias}}.[FundCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN CAST(CONCAT(N'fund:', COALESCE(NULLIF({{alias}}.[FundCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN CAST(CONCAT(N'Fund ', COALESCE(NULLIF({{alias}}.[FundCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN CAST(CONCAT(N'account:', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN CAST(CONCAT(N'Account ', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN CAST(CONCAT(N'account:', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN CAST(CONCAT(N'Account ', COALESCE(NULLIF({{alias}}.[AccountCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN CAST(CONCAT(N'activity:', COALESCE(NULLIF({{alias}}.[ActivityCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN CAST(CONCAT(N'Activity ', COALESCE(NULLIF({{alias}}.[ActivityCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN CAST(CONCAT(N'activity:', COALESCE(NULLIF({{alias}}.[ActivityCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN CAST(CONCAT(N'Activity ', COALESCE(NULLIF({{alias}}.[ActivityCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
                    (CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN CAST(CONCAT(N'purpose:', COALESCE(NULLIF({{alias}}.[PurposeCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN CAST(CONCAT(N'Purpose ', COALESCE(NULLIF({{alias}}.[PurposeCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
                    (CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN CAST(CONCAT(N'purpose:', COALESCE(NULLIF({{alias}}.[PurposeCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN CAST(CONCAT(N'Purpose ', COALESCE(NULLIF({{alias}}.[PurposeCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END)
            """;

    private sealed record ExpenseReviewTransactionRow(
        string Id,
        string Source,
        string? AccountingPeriod,
        DateTime? AccountingPeriodSort,
        string? EntityCode,
        string? EntityName,
        string? FinancialDeptCode,
        string? FinancialDeptName,
        string? FundCode,
        string? FundName,
        string? AccountCode,
        string? AccountName,
        string? AeProjectCode,
        string? AeProjectName,
        string? PurposeCode,
        string? PurposeName,
        string? ProgramCode,
        string? ProgramName,
        string? ActivityCode,
        string? ActivityName,
        string? Sfn,
        string? SfnLabel,
        decimal? Amount,
        bool Included);

    private sealed record ExpenseReviewReasonRow(
        string GroupId,
        string Code,
        string Label,
        int RowCount,
        decimal Amount);

    private sealed record ExpenseReviewFilterOptionRow(
        string Filter,
        string Value,
        string Label);
}
