using System.Runtime.CompilerServices;
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

    public async Task<UnmatchedJobCodesResponse> GetUnmatchedJobCodesAsync(
        FiscalYearCycle cycle,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var rows = (await connection.QueryAsync<UnmatchedJobCodeRow>(new CommandDefinition(
            UnmatchedJobCodesSql,
            CycleParameters(cycle),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken))).ToList();

        return new UnmatchedJobCodesResponse(
            cycle.FiscalYear,
            cycle.CycleStart,
            cycle.CycleEnd,
            rows.Select(row => new UnmatchedJobCodeDto(
                    row.JobCode,
                    row.TitleName,
                    row.StaffTypeCode,
                    row.Reason,
                    row.RowCount,
                    row.EmployeeCount,
                    row.Amount,
                    row.Fte))
                .ToList());
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

        await using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildTransactionsExportSql(request),
            parameters,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        var reasonsByGroup = new Dictionary<string, List<ExpenseReviewReasonRow>>(StringComparer.Ordinal);
        await foreach (var reason in reader.ReadUnbufferedAsync<ExpenseReviewReasonRow>()
                           .WithCancellation(cancellationToken))
        {
            AddReason(reasonsByGroup, reason);
        }

        var rows = reader.ReadUnbufferedAsync<ExpenseReviewTransactionRow>();

        await ExpenseReviewCsvWriter.WriteAsync(
            output,
            ToDtosAsync(rows, reasonsByGroup, cancellationToken),
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
            FROM
            (
                {{BuildGroupedReasonsSql("INNER JOIN #PagedGroupIds p ON p.[Id] = g.[Id]", null)}}
            ) r
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
                r.[GroupId],
                r.[Code],
                r.[Label],
                r.[RowCount],
                r.[Amount]
            FROM
            (
                {{BuildGroupedReasonsSql(string.Empty, includeClause)}}
            ) r
            ORDER BY r.[GroupId], r.[Label], r.[Code];

            SELECT
                {{GroupedSelectColumns}}
            FROM #Grouped g
            WHERE {{includeClause}}
            ORDER BY
                {{orderByClause}};
            """;
    }

    private static string BuildGroupedTempTablesSql(ExpenseReviewTransactionsRequest request)
    {
        var filters = request.Filters;
        var filterClause = BuildFilterClause(filters, "u");
        var exclusionReasonClause = BuildExclusionReasonFilterClause(filters, "u");
        var periodSelectColumns = request.DisplayByPeriod
            ? "u.[AccountingPeriod],\n                u.[AccountingPeriodSort],"
            : "CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod],\n                CAST(NULL AS DATE) AS [AccountingPeriodSort],";
        var periodGroupByColumns = request.DisplayByPeriod
            ? ",\n                u.[AccountingPeriod],\n                u.[AccountingPeriodSort]"
            : string.Empty;
        var zeroAmountHavingClause = request.IncludeZeroAmounts
            ? string.Empty
            : "\n            HAVING SUM(u.[Amount]) <> 0 OR SUM(u.[Amount]) IS NULL";

        return $$"""
            {{UnifiedTransactionsCte}}
            SELECT
                {{GroupIdExpression("u", request.DisplayByPeriod)}} AS [Id],
                u.[Source],
                {{periodSelectColumns}}
                u.[EntityCode],
                MAX(NULLIF(u.[EntityName], N'')) AS [EntityName],
                u.[FinancialDeptCode],
                MAX(NULLIF(u.[FinancialDeptName], N'')) AS [FinancialDeptName],
                u.[FundCode],
                MAX(NULLIF(u.[FundName], N'')) AS [FundName],
                u.[AccountCode],
                MAX(NULLIF(u.[AccountName], N'')) AS [AccountName],
                u.[AeProjectCode],
                MAX(NULLIF(u.[AeProjectName], N'')) AS [AeProjectName],
                u.[PurposeCode],
                MAX(NULLIF(u.[PurposeName], N'')) AS [PurposeName],
                u.[ProgramCode],
                MAX(NULLIF(u.[ProgramName], N'')) AS [ProgramName],
                u.[ActivityCode],
                MAX(NULLIF(u.[ActivityName], N'')) AS [ActivityName],
                MAX(u.[Sfn]) AS [Sfn],
                MAX(u.[SfnLabel]) AS [SfnLabel],
                SUM(u.[Amount]) AS [Amount],
                u.[Included],
                COUNT(1) AS [GroupReasonRowCount],
                SUM(COALESCE(u.[Amount], 0)) AS [GroupReasonAmount],
                SUM(CASE WHEN u.[ExcludedByDate] = 1 THEN 1 ELSE 0 END) AS [ExcludedByDateRowCount],
                SUM(CASE WHEN u.[ExcludedByDate] = 1 THEN COALESCE(u.[Amount], 0) ELSE 0 END) AS [ExcludedByDateAmount],
                SUM(CASE WHEN u.[Source] = N'AE' AND u.[AccountInUcPath] = 1 THEN 1 ELSE 0 END) AS [AeAccountInUcPathRowCount],
                SUM(CASE WHEN u.[Source] = N'AE' AND u.[AccountInUcPath] = 1 THEN COALESCE(u.[Amount], 0) ELSE 0 END) AS [AeAccountInUcPathAmount],
                SUM(CASE WHEN u.[Source] = N'UCP' AND u.[AccountNotInAE] = 1 THEN 1 ELSE 0 END) AS [UcPathAccountNotInAeRowCount],
                SUM(CASE WHEN u.[Source] = N'UCP' AND u.[AccountNotInAE] = 1 THEN COALESCE(u.[Amount], 0) ELSE 0 END) AS [UcPathAccountNotInAeAmount],
                SUM(CASE WHEN u.[Sfn] IS NULL THEN 1 ELSE 0 END) AS [ExpenseSfnUnresolvedRowCount],
                SUM(CASE WHEN u.[Sfn] IS NULL THEN COALESCE(u.[Amount], 0) ELSE 0 END) AS [ExpenseSfnUnresolvedAmount],
                SUM(CASE WHEN u.[Source] = N'UCP' AND u.[Account531010OnHatchFund] = 1 THEN 1 ELSE 0 END) AS [Account531010RowCount],
                SUM(CASE WHEN u.[Source] = N'UCP' AND u.[Account531010OnHatchFund] = 1 THEN COALESCE(u.[Amount], 0) ELSE 0 END) AS [Account531010Amount],
                MAX(CONVERT(TINYINT, u.[FinancialDeptIncludeInReport])) AS [FinancialDeptIncludeInReport],
                MAX(CONVERT(TINYINT, u.[FundIncludeInReport])) AS [FundIncludeInReport],
                MAX(CONVERT(TINYINT, u.[AccountIncludeInReport])) AS [AccountIncludeInReport],
                MAX(CONVERT(TINYINT, u.[ActivityIncludeInReport])) AS [ActivityIncludeInReport],
                MAX(CONVERT(TINYINT, u.[PurposeIncludeInReport])) AS [PurposeIncludeInReport]
            INTO #Grouped
            FROM Unified u
            WHERE {{filterClause}}
              AND {{exclusionReasonClause}}
            -- Sfn is single valued per group only because FundCode and AeProjectCode are both group keys; keep them if grouping ever changes.
            GROUP BY
                u.[Source],
                u.[Included],
                u.[EntityCode],
                u.[FinancialDeptCode],
                u.[FundCode],
                u.[AccountCode],
                u.[AeProjectCode],
                u.[PurposeCode],
                u.[ProgramCode],
                u.[ActivityCode]{{periodGroupByColumns}}{{zeroAmountHavingClause}};
            """;
    }

    private static string BuildGroupedReasonsSql(
        string joinSql,
        string? whereClause)
    {
        var additionalFilter = whereClause is null ? string.Empty : $"\n              AND {whereClause}";

        return $$"""
            SELECT
                g.[Id] AS [GroupId],
                reason.[Code],
                reason.[Label],
                reason.[RowCount],
                reason.[Amount]
            FROM #Grouped g
            {{joinSql}}
            CROSS APPLY
            (
                VALUES
                    {{GroupedReasonValuesSql("g")}}
            ) reason([Code], [Label], [RowCount], [Amount])
            WHERE reason.[RowCount] > 0{{additionalFilter}}
            """;
    }

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

    // In-window UCPath rows with no FTESFN, one row per job code. The view is
    // the source of truth for FteSfn; the title and staff type joins here only
    // explain which link in the chain is missing: no job code, no title, a
    // title with no staff type code, a staff type code with no StaffTypes row
    // (Titles has no foreign key to StaffTypes), or a staff type with no line.
    // Rows already excluded by the persisted flags (date, account not in the AE chart) are skipped; fund and other classification exclusions are not applied here.
    public const string UnmatchedJobCodesSql = """
        SELECT
            u.[JobCode],
            MAX(title.[Name]) AS [TitleName],
            MAX(title.[StaffTypeCode]) AS [StaffTypeCode],
            CASE
                WHEN u.[JobCode] IS NULL                                                THEN N'missingJobCode'
                WHEN MAX(CASE WHEN title.[TitleCode] IS NULL THEN 1 ELSE 0 END) = 1     THEN N'noTitle'
                WHEN MAX(title.[StaffTypeCode]) IS NULL                                 THEN N'titleHasNoStaffType'
                WHEN MAX(CASE WHEN staffType.[StaffTypeCode] IS NULL THEN 1 ELSE 0 END) = 1 THEN N'staffTypeNotFound'
                ELSE N'staffTypeHasNoLine'
            END AS [Reason],
            COUNT(1) AS [RowCount],
            COUNT(DISTINCT u.[EmployeeId]) AS [EmployeeCount],
            SUM(u.[Amount]) AS [Amount],
            SUM(u.[CalculatedFte]) AS [Fte]
        FROM [data].[UcPathTransactions] u
        JOIN [data].[v_TransactionSfn] txnSfn
            ON txnSfn.[Source] = N'UCPath' AND txnSfn.[LaborTransactionId] = u.[LaborTransactionId]
        LEFT JOIN [data].[Titles] title
            ON title.[TitleCode] = u.[JobCode]
        LEFT JOIN [data].[StaffTypes] staffType
            ON staffType.[StaffTypeCode] = title.[StaffTypeCode]
        WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
          AND COALESCE(u.[ExcludedByDate], 1) = 0
          AND COALESCE(u.[AccountNotInAE], 1) = 0
          AND txnSfn.[FteSfn] IS NULL
        GROUP BY u.[JobCode]
        ORDER BY SUM(u.[CalculatedFte]) DESC, u.[JobCode];
        """;

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
                incl.[ExpenseSfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                a.[Amount] AS [Amount],
                a.[ExcludedByDate],
                a.[AccountInUcPath],
                CAST(NULL AS BIT) AS [AccountNotInAE],
                incl.[FinancialDeptIncludeInReport],
                incl.[FundIncludeInReport],
                incl.[AccountIncludeInReport],
                incl.[ActivityIncludeInReport],
                incl.[PurposeIncludeInReport],
                incl.[Account531010OnHatchFund] AS [Account531010OnHatchFund],
                incl.[Included] AS [Included]
            FROM [data].[AETransactions] a
            LEFT JOIN [data].[v_TransactionInclusion] incl
                ON incl.[Source] = N'AE' AND incl.[AeTransactionId] = a.[Id]
            LEFT JOIN [data].[Sfns] sfn
                ON sfn.[Sfn] = incl.[ExpenseSfn]
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
                incl.[ExpenseSfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                u.[Amount] AS [Amount],
                u.[ExcludedByDate],
                CAST(NULL AS BIT) AS [AccountInUcPath],
                u.[AccountNotInAE],
                incl.[FinancialDeptIncludeInReport],
                incl.[FundIncludeInReport],
                incl.[AccountIncludeInReport],
                incl.[ActivityIncludeInReport],
                incl.[PurposeIncludeInReport],
                incl.[Account531010OnHatchFund] AS [Account531010OnHatchFund],
                incl.[Included] AS [Included]
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
                            WHEN periodValue.[PeriodNumber] BETWEEN 1 AND 6 THEN u.[FiscalYear] - 1
                            ELSE u.[FiscalYear]
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
            LEFT JOIN [data].[v_TransactionInclusion] incl
                ON incl.[Source] = N'UCPath' AND incl.[LaborTransactionId] = u.[LaborTransactionId]
            LEFT JOIN [data].[Sfns] sfn
                ON sfn.[Sfn] = incl.[ExpenseSfn]
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
        var reasonsByGroup = new Dictionary<string, List<ExpenseReviewReasonRow>>(StringComparer.Ordinal);
        foreach (var reason in reasonRows)
        {
            AddReason(reasonsByGroup, reason);
        }

        return rows
            .Select(row => ToDto(row, reasonsByGroup))
            .ToList();
    }

    private static async IAsyncEnumerable<ExpenseReviewTransactionDto> ToDtosAsync(
        IAsyncEnumerable<ExpenseReviewTransactionRow> rows,
        IReadOnlyDictionary<string, List<ExpenseReviewReasonRow>> reasonsByGroup,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await foreach (var row in rows.WithCancellation(cancellationToken))
        {
            yield return ToDto(row, reasonsByGroup);
        }
    }

    private static ExpenseReviewTransactionDto ToDto(
        ExpenseReviewTransactionRow row,
        IReadOnlyDictionary<string, List<ExpenseReviewReasonRow>> reasonsByGroup)
    {
        IReadOnlyList<ExpenseReviewExclusionReasonDto> reasons =
            reasonsByGroup.TryGetValue(row.Id, out var reasonRows)
                ? reasonRows
                    .Select(reason => new ExpenseReviewExclusionReasonDto(
                        reason.Code,
                        reason.Label,
                        reason.RowCount,
                        reason.Amount))
                    .ToList()
                : [];

        return new ExpenseReviewTransactionDto(
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
            reasons);
    }

    private static void AddReason(
        IDictionary<string, List<ExpenseReviewReasonRow>> reasonsByGroup,
        ExpenseReviewReasonRow reason)
    {
        if (!reasonsByGroup.TryGetValue(reason.GroupId, out var groupReasons))
        {
            groupReasons = [];
            reasonsByGroup.Add(reason.GroupId, groupReasons);
        }

        groupReasons.Add(reason);
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
                FROM
                (
                    VALUES
                        {ReasonValuesSql(alias)}
                ) selectedReason([Code], [Label])
                WHERE selectedReason.[Code] IN @exclusionReason
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

    private static string GroupedReasonValuesSql(string alias) =>
        $$"""
                    (CAST(N'excludedByDate' AS NVARCHAR(220)),
                     CAST(N'Excluded by date' AS NVARCHAR(500)),
                     {{alias}}.[ExcludedByDateRowCount],
                     {{alias}}.[ExcludedByDateAmount]),
                    (CAST(N'aeAccountInUcPath' AS NVARCHAR(220)),
                     CAST(N'AE account also in UCPath' AS NVARCHAR(500)),
                     {{alias}}.[AeAccountInUcPathRowCount],
                     {{alias}}.[AeAccountInUcPathAmount]),
                    (CAST(N'ucPathAccountNotInAE' AS NVARCHAR(220)),
                     CAST(N'UCPath account missing from AE chart' AS NVARCHAR(500)),
                     {{alias}}.[UcPathAccountNotInAeRowCount],
                     {{alias}}.[UcPathAccountNotInAeAmount]),
                    (CAST(N'sfn:unresolved' AS NVARCHAR(220)),
                     CAST(N'No SFN derived for this transaction' AS NVARCHAR(500)),
                     {{alias}}.[ExpenseSfnUnresolvedRowCount],
                     {{alias}}.[ExpenseSfnUnresolvedAmount]),
                    (CAST(N'account:531010' AS NVARCHAR(220)),
                     CAST(N'UCPath account 531010 on a Hatch fund' AS NVARCHAR(500)),
                     {{alias}}.[Account531010RowCount],
                     {{alias}}.[Account531010Amount]),
                    (CAST(N'financialDept:excluded' AS NVARCHAR(220)),
                     CAST(N'Excluded by financial department' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'financialDept:unclassified' AS NVARCHAR(220)),
                     CAST(N'Unclassified financial department' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'fund:excluded' AS NVARCHAR(220)),
                     CAST(N'Excluded by fund' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'fund:unclassified' AS NVARCHAR(220)),
                     CAST(N'Unclassified fund' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'account:excluded' AS NVARCHAR(220)),
                     CAST(N'Excluded by account' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'account:unclassified' AS NVARCHAR(220)),
                     CAST(N'Unclassified account' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'activity:excluded' AS NVARCHAR(220)),
                     CAST(N'Excluded by activity' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'activity:unclassified' AS NVARCHAR(220)),
                     CAST(N'Unclassified activity' AS NVARCHAR(500)),
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'purpose:excluded' AS NVARCHAR(220)),
                     CAST(N'Excluded by purpose' AS NVARCHAR(500)),
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN {{alias}}.[GroupReasonAmount] ELSE 0 END),
                    (CAST(N'purpose:unclassified' AS NVARCHAR(220)),
                     CAST(N'Unclassified purpose' AS NVARCHAR(500)),
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonRowCount] ELSE 0 END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN {{alias}}.[GroupReasonAmount] ELSE 0 END)
            """;

    private static string ReasonValuesSql(string alias) =>
        $$"""
                    (CASE WHEN {{alias}}.[ExcludedByDate] = 1 THEN CAST(N'excludedByDate' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ExcludedByDate] = 1 THEN CAST(N'Excluded by date' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Source] = N'AE' AND {{alias}}.[AccountInUcPath] = 1 THEN CAST(N'aeAccountInUcPath' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Source] = N'AE' AND {{alias}}.[AccountInUcPath] = 1 THEN CAST(N'AE account also in UCPath' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[AccountNotInAE] = 1 THEN CAST(N'ucPathAccountNotInAE' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[AccountNotInAE] = 1 THEN CAST(N'UCPath account missing from AE chart' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Sfn] IS NULL THEN CAST(N'sfn:unresolved' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Sfn] IS NULL THEN CAST(N'No SFN derived for this transaction' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[Account531010OnHatchFund] = 1 THEN CAST(N'account:531010' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[Source] = N'UCP' AND {{alias}}.[Account531010OnHatchFund] = 1 THEN CAST(N'UCPath account 531010 on a Hatch fund' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN CAST(N'financialDept:excluded' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] = 0 THEN CAST(N'Excluded by financial department' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN CAST(N'financialDept:unclassified' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FinancialDeptIncludeInReport] IS NULL THEN CAST(N'Unclassified financial department' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN CAST(N'fund:excluded' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] = 0 THEN CAST(N'Excluded by fund' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN CAST(N'fund:unclassified' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[FundIncludeInReport] IS NULL THEN CAST(N'Unclassified fund' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN CAST(N'account:excluded' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] = 0 THEN CAST(N'Excluded by account' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN CAST(N'account:unclassified' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[AccountIncludeInReport] IS NULL THEN CAST(N'Unclassified account' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN CAST(N'activity:excluded' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] = 0 THEN CAST(N'Excluded by activity' AS NVARCHAR(500)) END),
                    (CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN CAST(N'activity:unclassified' AS NVARCHAR(220)) END,
                     CASE WHEN {{alias}}.[ActivityIncludeInReport] IS NULL THEN CAST(N'Unclassified activity' AS NVARCHAR(500)) END),
                    (CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN CAST(N'purpose:excluded' AS NVARCHAR(220)) END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] = 0 THEN CAST(N'Excluded by purpose' AS NVARCHAR(500)) END),
                    (CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN CAST(N'purpose:unclassified' AS NVARCHAR(220)) END,
                     CASE WHEN COALESCE({{alias}}.[FundCode], N'') <> N'13U02' AND {{alias}}.[PurposeIncludeInReport] IS NULL THEN CAST(N'Unclassified purpose' AS NVARCHAR(500)) END)
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

    private sealed record UnmatchedJobCodeRow(
        string? JobCode,
        string? TitleName,
        string? StaffTypeCode,
        string Reason,
        int RowCount,
        int EmployeeCount,
        decimal Amount,
        decimal Fte);
}
