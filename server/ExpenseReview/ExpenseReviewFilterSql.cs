namespace Server.ExpenseReview;

// Dropdown-only facts: no transaction IDs, amounts, group hashes, or per-row chart descriptions.
internal static class ExpenseReviewFilterSql
{
    public static string Index => $$"""
        SELECT
            u.[Source],
            u.[EntityCode],
            u.[FinancialDeptCode],
            u.[FundCode],
            u.[AccountCode],
            u.[AeProjectCode],
            u.[PurposeCode],
            u.[ProgramCode],
            u.[ActivityCode],
            u.[FiscalYear],
            u.[PeriodIdentifier],
            u.[Sfn],
            {{ReasonMaskSql("u")}} AS [ExclusionReasonMask]
        INTO #FilterRaw
        FROM
        (
        SELECT DISTINCT
            CAST(N'AE' AS NVARCHAR(3)) AS [Source],
            a.[Entity] AS [EntityCode],
            a.[FinancialDepartment] AS [FinancialDeptCode],
            a.[Fund] AS [FundCode],
            a.[Account] AS [AccountCode],
            a.[Project] AS [AeProjectCode],
            a.[Purpose] AS [PurposeCode],
            a.[Program] AS [ProgramCode],
            a.[Activity] AS [ActivityCode],
            CAST(NULL AS INT) AS [FiscalYear],
            a.[PeriodName] AS [PeriodIdentifier],
            incl.[ExpenseSfn] AS [Sfn],
            incl.[ExcludedByDate],
            incl.[AccountInUcPath],
            CAST(NULL AS BIT) AS [AccountNotInAE],
            incl.[Account531010OnHatchFund],
            incl.[Sfn204NotOnProjectList],
            incl.[FinancialDeptIncludeInReport],
            incl.[FundIncludeInReport],
            incl.[AccountIncludeInReport],
            incl.[ActivityIncludeInReport],
            incl.[PurposeIncludeInReport],
            incl.[PurposeExempt]
        FROM [data].[AETransactions] a
        LEFT JOIN [data].[v_TransactionInclusion] incl
            ON incl.[Source] = N'AE' AND incl.[AeTransactionId] = a.[Id]
        WHERE TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) BETWEEN @cycleStart AND @cycleEnd
        UNION ALL
        SELECT DISTINCT
            CAST(N'UCP' AS NVARCHAR(3)) AS [Source],
            u.[Entity] AS [EntityCode],
            u.[FinancialDepartment] AS [FinancialDeptCode],
            u.[Fund] AS [FundCode],
            u.[Account] AS [AccountCode],
            u.[Project] AS [AeProjectCode],
            u.[Purpose] AS [PurposeCode],
            u.[Program] AS [ProgramCode],
            u.[Activity] AS [ActivityCode],
            u.[FiscalYear] AS [FiscalYear],
            u.[Period] AS [PeriodIdentifier],
            incl.[ExpenseSfn] AS [Sfn],
            incl.[ExcludedByDate],
            CAST(NULL AS BIT) AS [AccountInUcPath],
            incl.[AccountNotInAE],
            incl.[Account531010OnHatchFund],
            incl.[Sfn204NotOnProjectList],
            incl.[FinancialDeptIncludeInReport],
            incl.[FundIncludeInReport],
            incl.[AccountIncludeInReport],
            incl.[ActivityIncludeInReport],
            incl.[PurposeIncludeInReport],
            incl.[PurposeExempt]
        FROM [data].[UcPathTransactions] u
        LEFT JOIN [data].[v_TransactionInclusion] incl
            ON incl.[Source] = N'UCPath' AND incl.[LaborTransactionId] = u.[LaborTransactionId]
        WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
        ) u
        OPTION (MAXDOP 8);

        -- Materialization ensures date calculation and CLR formatting happen once per distinct pair.
        SELECT DISTINCT [Source], [FiscalYear], [PeriodIdentifier]
        INTO #PeriodKeys FROM #FilterRaw;
        SELECT k.*, d.[PeriodStart] AS [AccountingPeriodSort],
            CASE WHEN k.[Source] = N'AE' THEN k.[PeriodIdentifier]
                 ELSE FORMAT(d.[PeriodStart], 'MMM-yy', 'en-US') END AS [AccountingPeriod]
        INTO #FilterPeriods
        FROM #PeriodKeys k
        CROSS APPLY (SELECT TRY_CONVERT(INT, NULLIF(k.[PeriodIdentifier], '')) AS [PeriodNumber]) p
        CROSS APPLY
        (
            SELECT CASE WHEN k.[Source] = N'AE'
                THEN TRY_CONVERT(DATE, CONCAT('01-', k.[PeriodIdentifier]), 6)
                ELSE {{ExpenseReviewPeriodSql.UcPathPeriodStart("k.[FiscalYear]", "p.[PeriodNumber]")}} END AS [PeriodStart]
        ) d;

        -- Aggregate AE labels within this cycle; resolve UCPath chart labels once per distinct code.
        SELECT
            a.[Entity],
            a.[FinancialDepartment],
            a.[Fund],
            a.[Account],
            a.[Project],
            a.[Purpose],
            a.[Program],
            a.[Activity],
            MAX(NULLIF(a.[EntityDescription], N'')) AS [EntityDescription],
            MAX(NULLIF(a.[FinancialDepartmentDescription], N'')) AS [FinancialDepartmentDescription],
            MAX(NULLIF(a.[FundDescription], N'')) AS [FundDescription],
            MAX(NULLIF(a.[AccountDescription], N'')) AS [AccountDescription],
            MAX(NULLIF(a.[ProjectDescription], N'')) AS [ProjectDescription],
            MAX(NULLIF(a.[PurposeDescription], N'')) AS [PurposeDescription],
            MAX(NULLIF(a.[ProgramDescription], N'')) AS [ProgramDescription],
            MAX(NULLIF(a.[ActivityDescription], N'')) AS [ActivityDescription]
        INTO #AeFilterNames
        FROM [data].[AETransactions] a
        WHERE TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) BETWEEN @cycleStart AND @cycleEnd
        GROUP BY a.[Entity], a.[FinancialDepartment], a.[Fund], a.[Account], a.[Project], a.[Purpose], a.[Program], a.[Activity];

        SELECT names.[Filter], names.[Code], MAX(NULLIF(names.[Name], N'')) AS [Name]
        INTO #FilterNames
        FROM
        (
            SELECT n.[Filter], n.[Code], MAX(NULLIF(n.[Name], N'')) AS [Name]
            FROM #AeFilterNames a
            CROSS APPLY (VALUES
                (N'entity', a.[Entity], a.[EntityDescription]),
                (N'financialDept', a.[FinancialDepartment], a.[FinancialDepartmentDescription]),
                (N'fund', a.[Fund], a.[FundDescription]),
                (N'account', a.[Account], a.[AccountDescription]),
                (N'aeProject', a.[Project], a.[ProjectDescription]),
                (N'purpose', a.[Purpose], a.[PurposeDescription]),
                (N'program', a.[Program], a.[ProgramDescription]),
                (N'activity', a.[Activity], a.[ActivityDescription])
            ) n([Filter], [Code], [Name])
            GROUP BY n.[Filter], n.[Code]
            UNION ALL
            SELECT codes.[Filter], codes.[Code], NULLIF(chart.[Description], N'')
            FROM
            (
                SELECT DISTINCT n.[Filter], n.[Segment], n.[Code]
                FROM #FilterRaw u
                CROSS APPLY (VALUES
                    (N'entity', N'Entity', u.[EntityCode]),
                    (N'financialDept', N'FinancialDepartment', u.[FinancialDeptCode]),
                    (N'fund', N'Fund', u.[FundCode]),
                    (N'account', N'Account', u.[AccountCode]),
                    (N'aeProject', N'Project', u.[AeProjectCode]),
                    (N'purpose', N'Purpose', u.[PurposeCode]),
                    (N'program', N'Program', u.[ProgramCode]),
                    (N'activity', N'Activity', u.[ActivityCode])
                ) n([Filter], [Segment], [Code])
                WHERE u.[Source] = N'UCP' AND n.[Code] IS NOT NULL
            ) codes
            LEFT JOIN [data].[ChartSegments] chart ON chart.[SegmentName] = codes.[Segment] AND chart.[Code] = codes.[Code]
            UNION ALL
            SELECT N'sfn', codes.[Sfn], sfn.[Label]
            FROM (SELECT DISTINCT [Sfn] FROM #FilterRaw WHERE [Sfn] IS NOT NULL) codes
            LEFT JOIN [data].[Sfns] sfn ON sfn.[Sfn] = codes.[Sfn]
        ) names
        GROUP BY names.[Filter], names.[Code];

        {{Options}}

        SELECT
            u.[Source],
            u.[EntityCode],
            u.[FinancialDeptCode],
            u.[FundCode],
            u.[AccountCode],
            u.[AeProjectCode],
            p.[AccountingPeriod],
            u.[PurposeCode],
            u.[ProgramCode],
            u.[ActivityCode],
            u.[Sfn],
            u.[ExclusionReasonMask]
        FROM #FilterRaw u
        INNER JOIN #FilterPeriods p ON p.[Source] = u.[Source]
            AND (p.[FiscalYear] = u.[FiscalYear] OR (p.[FiscalYear] IS NULL AND u.[FiscalYear] IS NULL))
            AND (p.[PeriodIdentifier] = u.[PeriodIdentifier] OR (p.[PeriodIdentifier] IS NULL AND u.[PeriodIdentifier] IS NULL));
        """;

    private static string ReasonMaskSql(string alias) => string.Join(" + ",
        ExpenseReviewExclusionReasons.Definitions.Select(reason =>
            $"CASE WHEN {reason.SqlPredicate(alias)} THEN {reason.Bit} ELSE 0 END"));

    private static string CombinedMaskSql => string.Join(" + ",
        ExpenseReviewExclusionReasons.Definitions.Select(reason => $"MAX([ExclusionReasonMask] & {reason.Bit})"));

    private static string Options => $$"""
        DECLARE @allReasonMask INT;
        SELECT @allReasonMask = {{CombinedMaskSql}} FROM #FilterRaw;
        SELECT [Filter], [Value], [Label]
        FROM
        (
            SELECT codes.[Filter], codes.[Code] AS [Value],
                CONCAT(codes.[Code], CASE WHEN names.[Name] IS NULL THEN N'' ELSE CONCAT(N' - ', names.[Name]) END) AS [Label],
                CAST(codes.[Code] AS NVARCHAR(500)) AS [SortKey]
            FROM
            (
                SELECT DISTINCT n.[Filter], n.[Code]
                FROM #FilterRaw u
                CROSS APPLY (VALUES
                    (N'entity', u.[EntityCode]),
                    (N'financialDept', u.[FinancialDeptCode]),
                    (N'fund', u.[FundCode]),
                    (N'account', u.[AccountCode]),
                    (N'aeProject', u.[AeProjectCode]),
                    (N'purpose', u.[PurposeCode]),
                    (N'program', u.[ProgramCode]),
                    (N'activity', u.[ActivityCode]),
                    (N'sfn', u.[Sfn])
                ) n([Filter], [Code])
                WHERE n.[Code] IS NOT NULL
            ) codes
            LEFT JOIN #FilterNames names ON names.[Filter] = codes.[Filter] AND names.[Code] = codes.[Code]
            UNION ALL
            SELECT N'accountingPeriod', [AccountingPeriod], [AccountingPeriod],
                CONVERT(NVARCHAR(30), MIN([AccountingPeriodSort]), 126)
            FROM #FilterPeriods
            WHERE [AccountingPeriod] IS NOT NULL
            GROUP BY [AccountingPeriod]
            UNION ALL
            SELECT DISTINCT N'source', [Source],
                CASE [Source] WHEN N'AE' THEN N'Aggie Enterprise' ELSE N'UCPath' END, [Source]
            FROM #FilterRaw
            UNION ALL
            SELECT N'exclusionReason', reason.[Code], reason.[Label], reason.[Label]
            FROM (VALUES {{ReasonDefinitionsSql}}) reason([Bit], [Code], [Label])
            WHERE (@allReasonMask & reason.[Bit]) <> 0
        ) options
        ORDER BY [Filter], [SortKey], [Value], [Label];
        """;

    private static string ReasonDefinitionsSql => string.Join(",\n",
        ExpenseReviewExclusionReasons.Definitions.Select(reason => $"({reason.Bit}, N'{reason.Code}', N'{reason.Label}')"));
}
