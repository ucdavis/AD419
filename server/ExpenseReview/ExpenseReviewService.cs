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
            ["financialDept"] = "[FinancialDeptCode]",
            ["fund"] = "[FundCode]",
            ["account"] = "[AccountCode]",
            ["aeProject"] = "[AeProjectCode]",
            ["accountingPeriod"] = "[AccountingPeriodSort]",
            ["source"] = "[Source]",
            ["sfn"] = "[Sfn]",
            ["amount"] = "[Amount]",
            ["fte"] = "[Fte]",
        };

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

        return new ExpenseReviewTransactionsResponse(
            cycle.FiscalYear,
            cycle.CycleStart,
            cycle.CycleEnd,
            counts,
            totalCount,
            request.Page,
            request.PageSize,
            totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)request.PageSize),
            rows.Select(row => new ExpenseReviewTransactionDto(
                row.Id,
                row.SourceId,
                row.Source,
                new ExpenseReviewCodeNameDto(row.FinancialDeptCode, row.FinancialDeptName),
                new ExpenseReviewCodeNameDto(row.FundCode, row.FundName),
                new ExpenseReviewCodeNameDto(row.AccountCode, row.AccountName),
                new ExpenseReviewCodeNameDto(row.AeProjectCode, row.AeProjectName),
                row.AccountingPeriod,
                row.Sfn,
                row.SfnLabel,
                row.Amount,
                row.Fte,
                row.FteIncluded,
                row.Included)).ToList());
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
            Options("financialDept"),
            Options("fund"),
            Options("account"),
            Options("aeProject"),
            Options("accountingPeriod"),
            Options("source"),
            Options("sfn"));
    }

    public async Task WriteTransactionsCsvAsync(
        FiscalYearCycle cycle,
        ExpenseReviewTransactionsRequest request,
        IReadOnlyList<string> columnIds,
        Stream output,
        CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        var parameters = CreateParameters(cycle, request);
        var rows = await connection.QueryAsync<ExpenseReviewTransactionRow>(new CommandDefinition(
            BuildTransactionsExportSql(request),
            parameters,
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds,
            cancellationToken: cancellationToken));

        await ExpenseReviewCsvWriter.WriteAsync(
            output,
            rows.Select(ToDto),
            columnIds,
            cancellationToken);
    }

    public static string BuildTransactionsSql(ExpenseReviewTransactionsRequest request)
    {
        var includeClause = BuildIncludeClause(request.IncludeState);
        var transactionsSql = BuildTransactionRowsSql(
            "#Filtered",
            includeClause,
            BuildOrderByClause(request),
            "OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY");

        return $$"""
            {{BuildFilteredTransactionsCte(request.Filters)}}
            SELECT *
            INTO #Filtered
            FROM Filtered;

            SELECT
                COUNT(1) AS [All],
                COALESCE(SUM(CASE WHEN [Included] = 1 THEN 1 ELSE 0 END), 0) AS [Included],
                COALESCE(SUM(CASE WHEN [Included] = 0 THEN 1 ELSE 0 END), 0) AS [Excluded]
            FROM #Filtered;

            SELECT COUNT(1)
            FROM #Filtered
            WHERE {{includeClause}};

            {{transactionsSql}}
            """;
    }

    public static string BuildTransactionsExportSql(ExpenseReviewTransactionsRequest request)
    {
        return $$"""
            {{BuildFilteredTransactionsCte(request.Filters)}}
            {{BuildTransactionRowsSql(
                "Filtered",
                BuildIncludeClause(request.IncludeState),
                BuildOrderByClause(request),
                null)}}
            """;
    }

    private static string BuildFilteredTransactionsCte(ExpenseReviewFilters filters)
    {
        var filterClause = BuildFilterClause(filters);

        return $$"""
            {{UnifiedTransactionsCte}},
            Filtered AS
            (
                SELECT *
                FROM Unified
                WHERE {{filterClause}}
            )
            """;
    }

    private static string BuildTransactionRowsSql(
        string source,
        string includeClause,
        string orderByClause,
        string? paginationClause)
    {
        var paginationSql = string.IsNullOrWhiteSpace(paginationClause)
            ? string.Empty
            : $"\n{paginationClause}";

        return $$"""
            SELECT
                {{TransactionSelectColumns}}
            FROM {{source}}
            WHERE {{includeClause}}
            ORDER BY
                {{orderByClause}}{{paginationSql}};
            """;
    }

    private static string BuildIncludeClause(ExpenseReviewIncludeState includeState) =>
        includeState switch
        {
            ExpenseReviewIncludeState.Included => "[Included] = 1",
            ExpenseReviewIncludeState.Excluded => "[Included] = 0",
            _ => "1 = 1",
        };

    private static string BuildOrderByClause(ExpenseReviewTransactionsRequest request)
    {
        var sortExpression = SortExpressions[request.SortBy];
        var sortDirection = request.SortDescending ? "DESC" : "ASC";
        var orderByExpressions = new List<string>
        {
            $"CASE WHEN {sortExpression} IS NULL THEN 1 ELSE 0 END",
            $"{sortExpression} {sortDirection}",
        };

        foreach (var tieBreaker in new[] { "[Source]", "[SourceId]" })
        {
            if (!string.Equals(sortExpression, tieBreaker, StringComparison.OrdinalIgnoreCase))
            {
                orderByExpressions.Add(tieBreaker);
            }
        }

        return string.Join(",\n            ", orderByExpressions);
    }

    public static string FilterOptionsSql => $$"""
        {{UnifiedTransactionsCte}}
        SELECT DISTINCT
            CAST('financialDept' AS NVARCHAR(30)) AS [Filter],
            [FinancialDeptCode] AS [Value],
            COALESCE([FinancialDeptName], [FinancialDeptCode]) AS [Label]
        FROM Unified
        WHERE [FinancialDeptCode] IS NOT NULL
        UNION ALL
        SELECT DISTINCT
            CAST('fund' AS NVARCHAR(30)) AS [Filter],
            [FundCode] AS [Value],
            COALESCE([FundName], [FundCode]) AS [Label]
        FROM Unified
        WHERE [FundCode] IS NOT NULL
        UNION ALL
        SELECT DISTINCT
            CAST('account' AS NVARCHAR(30)) AS [Filter],
            [AccountCode] AS [Value],
            COALESCE([AccountName], [AccountCode]) AS [Label]
        FROM Unified
        WHERE [AccountCode] IS NOT NULL
        UNION ALL
        SELECT DISTINCT
            CAST('aeProject' AS NVARCHAR(30)) AS [Filter],
            [AeProjectCode] AS [Value],
            COALESCE([AeProjectName], [AeProjectCode]) AS [Label]
        FROM Unified
        WHERE [AeProjectCode] IS NOT NULL
        UNION ALL
        SELECT DISTINCT
            CAST('accountingPeriod' AS NVARCHAR(30)) AS [Filter],
            [AccountingPeriod] AS [Value],
            [AccountingPeriod] AS [Label]
        FROM Unified
        WHERE [AccountingPeriod] IS NOT NULL
        UNION ALL
        SELECT DISTINCT
            CAST('source' AS NVARCHAR(30)) AS [Filter],
            [Source] AS [Value],
            CASE [Source] WHEN 'AE' THEN 'Aggie Enterprise' ELSE 'UCPath' END AS [Label]
        FROM Unified
        UNION ALL
        SELECT DISTINCT
            CAST('sfn' AS NVARCHAR(30)) AS [Filter],
            [Sfn] AS [Value],
            COALESCE([SfnLabel], [Sfn]) AS [Label]
        FROM Unified
        WHERE [Sfn] IS NOT NULL
        ORDER BY [Filter], [Label], [Value];
        """;

    public const string UnifiedTransactionsCte = """
        WITH Unified AS
        (
            SELECT
                CAST(CONCAT('AE:', a.[Id]) AS NVARCHAR(160)) AS [Id],
                CAST(a.[Id] AS NVARCHAR(125)) AS [SourceId],
                CAST('AE' AS NVARCHAR(3)) AS [Source],
                a.[FinancialDepartment] AS [FinancialDeptCode],
                a.[FinancialDepartmentDescription] AS [FinancialDeptName],
                a.[Fund] AS [FundCode],
                a.[FundDescription] AS [FundName],
                a.[Account] AS [AccountCode],
                a.[AccountDescription] AS [AccountName],
                a.[Project] AS [AeProjectCode],
                a.[ProjectDescription] AS [AeProjectName],
                a.[PeriodName] AS [AccountingPeriod],
                TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) AS [AccountingPeriodSort],
                fundClass.[Sfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                a.[Amount] AS [Amount],
                CAST(NULL AS DECIMAL(9, 6)) AS [Fte],
                CAST(0 AS BIT) AS [FteIncluded],
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
                u.[LaborTransactionId] AS [SourceId],
                CAST('UCP' AS NVARCHAR(3)) AS [Source],
                u.[FinancialDepartment] AS [FinancialDeptCode],
                COALESCE(NULLIF(financialDeptSegment.[ValueDesc], ''), NULLIF(financialDeptSegment.[Description], '')) AS [FinancialDeptName],
                u.[Fund] AS [FundCode],
                COALESCE(NULLIF(fundSegment.[ValueDesc], ''), NULLIF(fundSegment.[Description], '')) AS [FundName],
                u.[Account] AS [AccountCode],
                COALESCE(NULLIF(accountSegment.[ValueDesc], ''), NULLIF(accountSegment.[Description], '')) AS [AccountName],
                u.[Project] AS [AeProjectCode],
                COALESCE(NULLIF(projectSegment.[ValueDesc], ''), NULLIF(projectSegment.[Description], '')) AS [AeProjectName],
                CASE
                    WHEN ucPeriod.[PeriodStart] IS NULL THEN NULL
                    ELSE FORMAT(ucPeriod.[PeriodStart], 'MMM-yy', 'en-US')
                END AS [AccountingPeriod],
                ucPeriod.[PeriodStart] AS [AccountingPeriodSort],
                fundClass.[Sfn] AS [Sfn],
                sfn.[Label] AS [SfnLabel],
                u.[Amount] AS [Amount],
                u.[CalculatedFte] AS [Fte],
                CASE
                    WHEN u.[ExcludedByDate] = 0
                     AND u.[AccountNotInAE] = 0
                     -- TODO: Seek stakeholder review on this fail-closed null/missing classification behavior.
                     AND COALESCE(financialDeptClass.[IncludeInReport], 0) = 1
                     AND COALESCE(fundClass.[IncludeInReport], 0) = 1
                     AND COALESCE(accountClass.[IncludeInReport], 0) = 1
                     AND COALESCE(activityClass.[IncludeInReport], 0) = 1
                     AND (u.[Fund] = '13U02' OR COALESCE(purposeClass.[IncludeInReport], 0) = 1)
                     AND COALESCE(ernClass.[IncludeInReport], 0) = 1
                    THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS [FteIncluded],
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
            LEFT JOIN [data].[SegmentClassifications] ernClass
                ON ernClass.[SegmentType] = 'Ern'
               AND ernClass.[Code] = u.[ErnCode]
            LEFT JOIN [data].[Sfns] sfn
                ON sfn.[Sfn] = fundClass.[Sfn]
            WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
        )
        """;

    private const string TransactionSelectColumns = """
        [Id],
        [SourceId],
        [Source],
        [FinancialDeptCode],
        [FinancialDeptName],
        [FundCode],
        [FundName],
        [AccountCode],
        [AccountName],
        [AeProjectCode],
        [AeProjectName],
        [AccountingPeriod],
        [Sfn],
        [SfnLabel],
        [Amount],
        [Fte],
        [FteIncluded],
        [Included]
        """;

    private SqlConnection CreateConnection()
    {
        var connectionString = DataDbConnection.Resolve(
            configuration,
            dataDbContext.Database.GetConnectionString());

        return new SqlConnection(connectionString);
    }

    private static ExpenseReviewTransactionDto ToDto(ExpenseReviewTransactionRow row) =>
        new(
            row.Id,
            row.SourceId,
            row.Source,
            new ExpenseReviewCodeNameDto(row.FinancialDeptCode, row.FinancialDeptName),
            new ExpenseReviewCodeNameDto(row.FundCode, row.FundName),
            new ExpenseReviewCodeNameDto(row.AccountCode, row.AccountName),
            new ExpenseReviewCodeNameDto(row.AeProjectCode, row.AeProjectName),
            row.AccountingPeriod,
            row.Sfn,
            row.SfnLabel,
            row.Amount,
            row.Fte,
            row.FteIncluded,
            row.Included);

    private static DynamicParameters CreateParameters(FiscalYearCycle cycle, ExpenseReviewTransactionsRequest request)
    {
        var parameters = CycleParameters(cycle);
        parameters.Add("offset", (request.Page - 1) * request.PageSize);
        parameters.Add("pageSize", request.PageSize);

        AddList("financialDept", request.Filters.FinancialDept);
        AddList("fund", request.Filters.Fund);
        AddList("account", request.Filters.Account);
        AddList("aeProject", request.Filters.AeProject);
        AddList("accountingPeriod", request.Filters.AccountingPeriod);
        AddList("source", request.Filters.Source);
        AddList("sfn", request.Filters.Sfn);

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

    private static string BuildFilterClause(ExpenseReviewFilters filters)
    {
        var clauses = new List<string>();

        AddListFilter(filters.FinancialDept, "[FinancialDeptCode] IN @financialDept");
        AddListFilter(filters.Fund, "[FundCode] IN @fund");
        AddListFilter(filters.Account, "[AccountCode] IN @account");
        AddListFilter(filters.AeProject, "[AeProjectCode] IN @aeProject");
        AddListFilter(filters.AccountingPeriod, "[AccountingPeriod] IN @accountingPeriod");
        AddListFilter(filters.Source, "[Source] IN @source");
        AddListFilter(filters.Sfn, "[Sfn] IN @sfn");

        return clauses.Count == 0 ? "1 = 1" : string.Join("\n                  AND ", clauses);

        void AddListFilter(IReadOnlyList<string> values, string clause)
        {
            if (values.Count > 0)
            {
                clauses.Add(clause);
            }
        }
    }

    private sealed record ExpenseReviewTransactionRow(
        string Id,
        string SourceId,
        string Source,
        string? FinancialDeptCode,
        string? FinancialDeptName,
        string? FundCode,
        string? FundName,
        string? AccountCode,
        string? AccountName,
        string? AeProjectCode,
        string? AeProjectName,
        string? AccountingPeriod,
        string? Sfn,
        string? SfnLabel,
        decimal? Amount,
        decimal? Fte,
        bool FteIncluded,
        bool Included);

    private sealed record ExpenseReviewFilterOptionRow(
        string Filter,
        string Value,
        string Label);
}
