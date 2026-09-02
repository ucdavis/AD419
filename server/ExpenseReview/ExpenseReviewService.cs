using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Server.Core.Data;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public sealed class ExpenseReviewService(
    DataDbContext dataDbContext,
    IConfiguration configuration,
    IExpenseReviewCacheService expenseReviewCacheService) : IExpenseReviewService
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
        await expenseReviewCacheService.EnsureCachePreparedAsync(cycle, cancellationToken);

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
        await expenseReviewCacheService.EnsureCachePreparedAsync(cycle, cancellationToken);

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
        await expenseReviewCacheService.EnsureCachePreparedAsync(cycle, cancellationToken);

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
            FROM
            (
                {{BuildAggregatedReasonsSql("INNER JOIN #PagedGroupIds p ON p.[Id] = t.[GroupId]", null)}}
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
            FROM
            (
                {{BuildAggregatedReasonsSql("INNER JOIN #Grouped g ON g.[Id] = t.[GroupId]", includeClause)}}
            ) r
            ORDER BY r.[GroupId], r.[Label], r.[Code];
            """;
    }

    private static string BuildGroupedTempTablesSql(ExpenseReviewTransactionsRequest request)
    {
        var filters = request.Filters;
        var filterClause = BuildFilterClause(filters, "f");
        var exclusionReasonClause = BuildExclusionReasonFilterClause(filters, "f");
        var periodSelectColumns = request.DisplayByPeriod
            ? "t.[AccountingPeriod],\n                t.[AccountingPeriodSort],"
            : "CAST(NULL AS NVARCHAR(20)) AS [AccountingPeriod],\n                CAST(NULL AS DATE) AS [AccountingPeriodSort],";
        var periodGroupByColumns = request.DisplayByPeriod
            ? ",\n                t.[AccountingPeriod],\n                t.[AccountingPeriodSort]"
            : string.Empty;

        return $$"""
            SELECT
                {{GroupIdExpression("f", request.DisplayByPeriod)}} AS [GroupId],
                f.[TransactionId],
                f.[Source],
                f.[AccountingPeriod],
                f.[AccountingPeriodSort],
                f.[EntityCode],
                f.[EntityName],
                f.[FinancialDeptCode],
                f.[FinancialDeptName],
                f.[FundCode],
                f.[FundName],
                f.[AccountCode],
                f.[AccountName],
                f.[AeProjectCode],
                f.[AeProjectName],
                f.[PurposeCode],
                f.[PurposeName],
                f.[ProgramCode],
                f.[ProgramName],
                f.[ActivityCode],
                f.[ActivityName],
                f.[Sfn],
                f.[SfnLabel],
                f.[Amount],
                f.[Included]
            INTO #FilteredTransactions
            FROM [data].[ExpenseReviewTransactionFacts] f
            WHERE f.[CycleStart] = @cycleStart
              AND f.[CycleEnd] = @cycleEnd
              AND {{filterClause}}
              AND {{exclusionReasonClause}};

            SELECT
                t.[GroupId] AS [Id],
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
                t.[GroupId],
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

            """;
    }

    private static string BuildAggregatedReasonsSql(string joinSql, string? whereClause) =>
        $$"""
            SELECT
                t.[GroupId],
                r.[Code],
                r.[Label],
                COUNT(1) AS [RowCount],
                SUM(COALESCE(r.[Amount], 0)) AS [Amount]
            FROM #FilteredTransactions t
            {{joinSql}}
            INNER JOIN [data].[ExpenseReviewTransactionReasons] r
                ON r.[CycleStart] = @cycleStart
               AND r.[CycleEnd] = @cycleEnd
               AND r.[TransactionId] = t.[TransactionId]
            {{(whereClause is null ? string.Empty : $"WHERE {whereClause}")}}
            GROUP BY t.[GroupId], r.[Code], r.[Label]
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
        SELECT [Filter], [Value], [Label]
        FROM
        (
        SELECT
            CAST('entity' AS NVARCHAR(30)) AS [Filter],
            [EntityCode] AS [Value],
            {{CodeNameLabelExpression("[EntityCode]", "MAX(NULLIF([EntityName], N''))")}} AS [Label],
            CAST([EntityCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [EntityCode] IS NOT NULL
        GROUP BY [EntityCode]
        UNION ALL
        SELECT
            CAST('financialDept' AS NVARCHAR(30)) AS [Filter],
            [FinancialDeptCode] AS [Value],
            {{CodeNameLabelExpression("[FinancialDeptCode]", "MAX(NULLIF([FinancialDeptName], N''))")}} AS [Label],
            CAST([FinancialDeptCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [FinancialDeptCode] IS NOT NULL
        GROUP BY [FinancialDeptCode]
        UNION ALL
        SELECT
            CAST('fund' AS NVARCHAR(30)) AS [Filter],
            [FundCode] AS [Value],
            {{CodeNameLabelExpression("[FundCode]", "MAX(NULLIF([FundName], N''))")}} AS [Label],
            CAST([FundCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [FundCode] IS NOT NULL
        GROUP BY [FundCode]
        UNION ALL
        SELECT
            CAST('account' AS NVARCHAR(30)) AS [Filter],
            [AccountCode] AS [Value],
            {{CodeNameLabelExpression("[AccountCode]", "MAX(NULLIF([AccountName], N''))")}} AS [Label],
            CAST([AccountCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [AccountCode] IS NOT NULL
        GROUP BY [AccountCode]
        UNION ALL
        SELECT
            CAST('aeProject' AS NVARCHAR(30)) AS [Filter],
            [AeProjectCode] AS [Value],
            {{CodeNameLabelExpression("[AeProjectCode]", "MAX(NULLIF([AeProjectName], N''))")}} AS [Label],
            CAST([AeProjectCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [AeProjectCode] IS NOT NULL
        GROUP BY [AeProjectCode]
        UNION ALL
        SELECT
            CAST('accountingPeriod' AS NVARCHAR(30)) AS [Filter],
            [AccountingPeriod] AS [Value],
            [AccountingPeriod] AS [Label],
            CONVERT(NVARCHAR(30), MIN([AccountingPeriodSort]), 126) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [AccountingPeriod] IS NOT NULL
        GROUP BY [AccountingPeriod]
        UNION ALL
        SELECT
            CAST('purpose' AS NVARCHAR(30)) AS [Filter],
            [PurposeCode] AS [Value],
            {{CodeNameLabelExpression("[PurposeCode]", "MAX(NULLIF([PurposeName], N''))")}} AS [Label],
            CAST([PurposeCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [PurposeCode] IS NOT NULL
        GROUP BY [PurposeCode]
        UNION ALL
        SELECT
            CAST('program' AS NVARCHAR(30)) AS [Filter],
            [ProgramCode] AS [Value],
            {{CodeNameLabelExpression("[ProgramCode]", "MAX(NULLIF([ProgramName], N''))")}} AS [Label],
            CAST([ProgramCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [ProgramCode] IS NOT NULL
        GROUP BY [ProgramCode]
        UNION ALL
        SELECT
            CAST('activity' AS NVARCHAR(30)) AS [Filter],
            [ActivityCode] AS [Value],
            {{CodeNameLabelExpression("[ActivityCode]", "MAX(NULLIF([ActivityName], N''))")}} AS [Label],
            CAST([ActivityCode] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [ActivityCode] IS NOT NULL
        GROUP BY [ActivityCode]
        UNION ALL
        SELECT
            CAST('sfn' AS NVARCHAR(30)) AS [Filter],
            [Sfn] AS [Value],
            {{CodeNameLabelExpression("[Sfn]", "MAX(NULLIF([SfnLabel], N''))")}} AS [Label],
            CAST([Sfn] AS NVARCHAR(500)) AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
          AND [Sfn] IS NOT NULL
        GROUP BY [Sfn]
        UNION ALL
        SELECT DISTINCT
            CAST('source' AS NVARCHAR(30)) AS [Filter],
            [Source] AS [Value],
            CASE [Source] WHEN N'AE' THEN N'Aggie Enterprise' ELSE N'UCPath' END AS [Label],
            [Source] AS [SortKey]
        FROM [data].[ExpenseReviewTransactionFacts]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
        UNION ALL
        SELECT DISTINCT
            CAST('exclusionReason' AS NVARCHAR(30)) AS [Filter],
            [Code] AS [Value],
            [Label],
            [Label] AS [SortKey]
        FROM [data].[ExpenseReviewTransactionReasons]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd
        ) options
        ORDER BY [Filter], [SortKey], [Value], [Label];
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
                FROM [data].[ExpenseReviewTransactionReasons] selectedReason
                WHERE selectedReason.[CycleStart] = @cycleStart
                  AND selectedReason.[CycleEnd] = @cycleEnd
                  AND selectedReason.[TransactionId] = {alias}.[TransactionId]
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
