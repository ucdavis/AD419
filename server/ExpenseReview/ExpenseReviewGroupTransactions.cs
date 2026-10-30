using System.Runtime.CompilerServices;
using System.Text.Json;
using Dapper;
using Server.Core.Data;
using Server.Models;
using Server.Models.ExpenseReview;

namespace Server.ExpenseReview;

public sealed partial class ExpenseReviewService
{
    public async Task<ExpenseReviewGroupTransactionsResponse?> GetGroupTransactionsAsync(
        FiscalYearCycle cycle, ExpenseReviewGroupTransactionsRequest request, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildGroupTransactionsSql(request), GroupParameters(cycle, request),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken));
        var groups = (await reader.ReadAsync<ExpenseReviewTransactionRow>()).ToList();
        var reasons = (await reader.ReadAsync<ExpenseReviewReasonRow>()).ToList();
        var transactionCount = await reader.ReadSingleAsync<int>();
        var totals = await reader.ReadSingleAsync<ExpenseReviewTotalsRow>();
        var rows = (await reader.ReadAsync<DetailRow>()).Select(ToDetailDto).ToArray();
        if (groups.Count == 0) return null;
        return new(cycle.FiscalYear, cycle.CycleStart, cycle.CycleEnd, ToDtos(groups, reasons)[0],
            transactionCount, totals.TotalCount, totals.TotalAmount,
            request.Context.Page, request.Context.PageSize,
            (int)Math.Ceiling((double)totals.TotalCount / request.Context.PageSize), rows);
    }

    public async Task WriteGroupTransactionsCsvAsync(FiscalYearCycle cycle,
        ExpenseReviewGroupTransactionsRequest request, ExpenseReviewTransactionDto group,
        Stream output, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        using var reader = await connection.QueryMultipleAsync(new CommandDefinition(
            BuildGroupTransactionsSql(request, export: true), GroupParameters(cycle, request),
            commandTimeout: DataDbConnection.ImportCommandTimeoutSeconds, cancellationToken: cancellationToken));
        await ExpenseReviewDetailCsvWriter.WriteAsync(output, Rows(cancellationToken), cycle, group, cancellationToken);

        async IAsyncEnumerable<ExpenseReviewTransactionDetailDto> Rows(
            [EnumeratorCancellation] CancellationToken token)
        {
            await foreach (var row in reader.ReadUnbufferedAsync<DetailRow>().WithCancellation(token))
                yield return ToDetailDto(row);
        }
    }

    private static DynamicParameters GroupParameters(FiscalYearCycle cycle, ExpenseReviewGroupTransactionsRequest request)
    {
        var parameters = CreateParameters(cycle, request.Context);
        parameters.Add("groupId", request.GroupId);
        parameters.Add("search", request.Search);
        return parameters;
    }

    public static string BuildGroupTransactionsSql(ExpenseReviewGroupTransactionsRequest request, bool export = false)
    {
        var context = request.Context;
        var sort = ExpenseReviewGroupTransactionsParser.SortColumns[request.SortBy];
        var direction = request.SortDescending ? "DESC" : "ASC";
        var orderBy = request.SortBy.Equals("id", StringComparison.OrdinalIgnoreCase)
            ? $"[AeTransactionId] {direction}, [LaborTransactionId] {direction}, [Id] ASC"
            : $"CASE WHEN [{sort}] IS NULL THEN 1 ELSE 0 END, [{sort}] {direction}, [Id] ASC";
        var pagination = export ? "" : "OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";
        // Establish the full filtered group before search. Zero-dollar members must never be filtered individually.
        return $$"""
            {{BuildGroupedTempTablesSql(context)}}
            DELETE FROM #Grouped WHERE [Id] <> @groupId OR NOT ({{BuildIncludeClause(context.IncludeState, "")}});

            {{UnifiedTransactionsCte}}
            SELECT u.* INTO #Members FROM Unified u
            WHERE {{GroupIdExpression("u", context.DisplayByPeriod)}} = @groupId
              AND EXISTS (SELECT 1 FROM #Grouped)
              AND {{BuildFilterClause(context.Filters, "u")}}
              AND {{BuildExclusionReasonFilterClause(context.Filters, "u")}};

            SELECT m.[Id], m.[AeTransactionId], m.[LaborTransactionId],
                m.[AccountingPeriod], m.[AccountingPeriodSort], m.[Amount],
                COALESCE(CAST(u.[PayPeriodEndDate] AS DATETIME2), CAST(a.[JournalAcctDate] AS DATETIME2)) AS [TransactionDate],
                u.[EmployeeName], u.[PositionNumber], u.[ErnCode], u.[ErnDescription],
                CASE u.[FringeBenefitSalaryCd] WHEN 'S' THEN N'Salary' WHEN 'F' THEN N'Fringe' END AS [SalaryFringe],
                u.[JobCode], u.[Hours], u.[CalculatedFte],
                CONVERT(NVARCHAR(30), a.[AccountingSequenceNumber]) AS [AccountingSequenceNumber],
                a.[AccountingSequenceNumber] AS [SequenceNumberSort],
                a.[JournalName], a.[JournalLineDescription] AS [LineDescription], a.[DocumentType], a.[JournalReference],
                (SELECT r.[Code], r.[Label], 1 AS [RowCount], COALESCE(m.[Amount], 0) AS [Amount]
                 FROM (VALUES {{ReasonValuesSql("m")}}) r([Code], [Label])
                 WHERE r.[Code] IS NOT NULL ORDER BY r.[Label], r.[Code] FOR JSON PATH) AS [ReasonsJson]
            INTO #Details
            FROM #Members m
            LEFT JOIN [data].[UcPathTransactions] u ON m.[Source] = N'UCP' AND m.[LaborTransactionId] = u.[LaborTransactionId]
            LEFT JOIN [data].[AETransactions] a ON m.[Source] = N'AE' AND m.[AeTransactionId] = a.[Id];

            {{(export ? "" : $$"""
            SELECT {{GroupedSelectColumns}} FROM #Grouped;
            {{BuildGroupedReasonsSql("", null)}};
            SELECT COUNT(1) FROM #Details;
            """)}}

            DELETE FROM #Details WHERE @search IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM (VALUES
                    ([Id]), ([AccountingPeriod]), ([EmployeeName]), ([PositionNumber]), ([ErnCode]),
                    ([ErnDescription]), ([SalaryFringe]), ([JobCode]), ([AccountingSequenceNumber]),
                    ([JournalName]), ([LineDescription]), ([DocumentType]), ([JournalReference])) textFields([Value])
                WHERE CHARINDEX(@search COLLATE Latin1_General_100_CI_AS, textFields.[Value] COLLATE Latin1_General_100_CI_AS) > 0)
              AND NOT EXISTS (
                SELECT 1 FROM OPENJSON([ReasonsJson]) WITH ([Label] NVARCHAR(500) '$.Label') reasons
                WHERE CHARINDEX(@search COLLATE Latin1_General_100_CI_AS, reasons.[Label] COLLATE Latin1_General_100_CI_AS) > 0);

            {{(export ? "" : "SELECT COUNT(1) AS [TotalCount], COALESCE(SUM([Amount]), 0) AS [TotalAmount] FROM #Details;")}}
            SELECT * FROM #Details
            ORDER BY {{orderBy}}
            {{pagination}};
            """;
    }

    private sealed record DetailRow : ExpenseReviewTransactionDetailDto
    {
        public string ReasonsJson { get; init; } = "[]";
    }

    private static ExpenseReviewTransactionDetailDto ToDetailDto(DetailRow row) => new()
    {
        Id = row.Id.StartsWith("AE:", StringComparison.Ordinal) ? row.Id[3..] : row.Id[4..],
        TransactionDate = row.TransactionDate, AccountingPeriod = row.AccountingPeriod,
        EmployeeName = row.EmployeeName, PositionNumber = row.PositionNumber, ErnCode = row.ErnCode,
        ErnDescription = row.ErnDescription, SalaryFringe = row.SalaryFringe, JobCode = row.JobCode,
        Hours = row.Hours, CalculatedFte = row.CalculatedFte, AccountingSequenceNumber = row.AccountingSequenceNumber,
        JournalName = row.JournalName, LineDescription = row.LineDescription, DocumentType = row.DocumentType,
        JournalReference = row.JournalReference, Amount = row.Amount,
        ExclusionReasons = JsonSerializer.Deserialize<ExpenseReviewExclusionReasonDto[]>(row.ReasonsJson) ?? [],
    };
}
