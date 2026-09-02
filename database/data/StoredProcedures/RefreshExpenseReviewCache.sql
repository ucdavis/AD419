CREATE PROCEDURE [data].[RefreshExpenseReviewCache]
    @cycleStart DATE,
    @cycleEnd   DATE,
    @force      BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @cycleStart IS NULL OR @cycleEnd IS NULL
        THROW 50000, '@cycleStart and @cycleEnd are required.', 1;

    IF @cycleStart > @cycleEnd
        THROW 50000, '@cycleStart must not be after @cycleEnd.', 1;

    BEGIN TRANSACTION;

    DECLARE @lockResult INT;
    DECLARE @lockResource NVARCHAR(200) = CONCAT(
        N'ExpenseReviewCache:',
        CONVERT(NVARCHAR(10), @cycleStart, 23),
        N':',
        CONVERT(NVARCHAR(10), @cycleEnd, 23));

    EXEC @lockResult = sp_getapplock
        @Resource = @lockResource,
        @LockMode = 'Exclusive',
        @LockOwner = 'Transaction',
        @LockTimeout = 60000;

    IF @lockResult < 0
        THROW 50000, 'Could not acquire the expense review cache refresh lock.', 1;

    IF @force = 0
       AND EXISTS
       (
           SELECT 1
           FROM [data].[ExpenseReviewCacheStatus]
           WHERE [CycleStart] = @cycleStart
             AND [CycleEnd] = @cycleEnd
       )
    BEGIN
        SELECT
            [FactRowCount],
            [ReasonRowCount],
            CAST(0 AS BIT) AS [Refreshed]
        FROM [data].[ExpenseReviewCacheStatus]
        WHERE [CycleStart] = @cycleStart
          AND [CycleEnd] = @cycleEnd;

        COMMIT TRANSACTION;
        RETURN;
    END;

    DELETE FROM [data].[ExpenseReviewTransactionReasons]
    WHERE [CycleStart] = @cycleStart
      AND [CycleEnd] = @cycleEnd;

    DELETE FROM [data].[ExpenseReviewTransactionFacts]
    WHERE [CycleStart] = @cycleStart
      AND [CycleEnd] = @cycleEnd;

    DELETE FROM [data].[ExpenseReviewCacheStatus]
    WHERE [CycleStart] = @cycleStart
      AND [CycleEnd] = @cycleEnd;

    CREATE TABLE #Unified
    (
        [TransactionId]                    NVARCHAR(160)  NOT NULL,
        [Source]                           NVARCHAR(3)    NOT NULL,
        [EntityCode]                       NVARCHAR(50)   NULL,
        [EntityName]                       NVARCHAR(800)  NULL,
        [FinancialDeptCode]                NVARCHAR(50)   NULL,
        [FinancialDeptName]                NVARCHAR(800)  NULL,
        [FundCode]                         NVARCHAR(50)   NULL,
        [FundName]                         NVARCHAR(800)  NULL,
        [AccountCode]                      NVARCHAR(50)   NULL,
        [AccountName]                      NVARCHAR(800)  NULL,
        [AeProjectCode]                    NVARCHAR(300)  NULL,
        [AeProjectName]                    NVARCHAR(800)  NULL,
        [PurposeCode]                      NVARCHAR(50)   NULL,
        [PurposeName]                      NVARCHAR(800)  NULL,
        [ProgramCode]                      NVARCHAR(50)   NULL,
        [ProgramName]                      NVARCHAR(800)  NULL,
        [ActivityCode]                     NVARCHAR(50)   NULL,
        [ActivityName]                     NVARCHAR(800)  NULL,
        [AccountingPeriod]                 NVARCHAR(30)   NULL,
        [AccountingPeriodSort]             DATE           NULL,
        [Sfn]                              NVARCHAR(10)   NULL,
        [SfnLabel]                         NVARCHAR(100)  NULL,
        [Amount]                           DECIMAL(19, 4) NULL,
        [ExcludedByDate]                   BIT            NULL,
        [AccountInUcPath]                  BIT            NULL,
        [AccountNotInAE]                   BIT            NULL,
        [FinancialDeptIncludeInReport]     BIT            NULL,
        [FundIncludeInReport]              BIT            NULL,
        [AccountIncludeInReport]           BIT            NULL,
        [ActivityIncludeInReport]          BIT            NULL,
        [PurposeIncludeInReport]           BIT            NULL,
        [Included]                         BIT            NOT NULL
    );

    INSERT INTO #Unified
    (
        [TransactionId],
        [Source],
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
        [AccountingPeriod],
        [AccountingPeriodSort],
        [Sfn],
        [SfnLabel],
        [Amount],
        [ExcludedByDate],
        [AccountInUcPath],
        [AccountNotInAE],
        [FinancialDeptIncludeInReport],
        [FundIncludeInReport],
        [AccountIncludeInReport],
        [ActivityIncludeInReport],
        [PurposeIncludeInReport],
        [Included]
    )
    SELECT
        CAST(CONCAT('AE:', a.[Id]) AS NVARCHAR(160)) AS [TransactionId],
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
        CAST(CONCAT('UCP:', u.[LaborTransactionId]) AS NVARCHAR(160)) AS [TransactionId],
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
    WHERE CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd;

    INSERT INTO [data].[ExpenseReviewTransactionFacts]
    (
        [CycleStart],
        [CycleEnd],
        [TransactionId],
        [Source],
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
        [AccountingPeriod],
        [AccountingPeriodSort],
        [Sfn],
        [SfnLabel],
        [Amount],
        [Included]
    )
    SELECT
        @cycleStart,
        @cycleEnd,
        [TransactionId],
        [Source],
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
        [AccountingPeriod],
        [AccountingPeriodSort],
        [Sfn],
        [SfnLabel],
        [Amount],
        [Included]
    FROM #Unified;

    INSERT INTO [data].[ExpenseReviewTransactionReasons]
    (
        [CycleStart],
        [CycleEnd],
        [TransactionId],
        [Code],
        [Label],
        [Amount]
    )
    SELECT
        @cycleStart,
        @cycleEnd,
        u.[TransactionId],
        reason.[Code],
        reason.[Label],
        u.[Amount]
    FROM #Unified u
    CROSS APPLY
    (
        VALUES
            (CASE WHEN u.[ExcludedByDate] = 1 THEN CAST(N'excludedByDate' AS NVARCHAR(220)) END,
             CASE WHEN u.[ExcludedByDate] = 1 THEN CAST(N'Date excluded' AS NVARCHAR(500)) END),
            (CASE WHEN u.[Source] = N'AE' AND u.[AccountInUcPath] = 1 THEN CAST(CONCAT(N'aeAccountInUcPath:', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)')) AS NVARCHAR(220)) END,
             CASE WHEN u.[Source] = N'AE' AND u.[AccountInUcPath] = 1 THEN CAST(CONCAT(N'AE account ', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N' also in UCPath') AS NVARCHAR(500)) END),
            (CASE WHEN u.[Source] = N'UCP' AND u.[AccountNotInAE] = 1 THEN CAST(CONCAT(N'ucPathAccountNotInAE:', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)')) AS NVARCHAR(220)) END,
             CASE WHEN u.[Source] = N'UCP' AND u.[AccountNotInAE] = 1 THEN CAST(CONCAT(N'UCPath account ', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N' missing from AE chart') AS NVARCHAR(500)) END),
            (CASE WHEN u.[FinancialDeptIncludeInReport] = 0 THEN CAST(CONCAT(N'financialDept:', COALESCE(NULLIF(u.[FinancialDeptCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
             CASE WHEN u.[FinancialDeptIncludeInReport] = 0 THEN CAST(CONCAT(N'Financial Dept ', COALESCE(NULLIF(u.[FinancialDeptCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
            (CASE WHEN u.[FinancialDeptIncludeInReport] IS NULL THEN CAST(CONCAT(N'financialDept:', COALESCE(NULLIF(u.[FinancialDeptCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
             CASE WHEN u.[FinancialDeptIncludeInReport] IS NULL THEN CAST(CONCAT(N'Financial Dept ', COALESCE(NULLIF(u.[FinancialDeptCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
            (CASE WHEN u.[FundIncludeInReport] = 0 THEN CAST(CONCAT(N'fund:', COALESCE(NULLIF(u.[FundCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
             CASE WHEN u.[FundIncludeInReport] = 0 THEN CAST(CONCAT(N'Fund ', COALESCE(NULLIF(u.[FundCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
            (CASE WHEN u.[FundIncludeInReport] IS NULL THEN CAST(CONCAT(N'fund:', COALESCE(NULLIF(u.[FundCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
             CASE WHEN u.[FundIncludeInReport] IS NULL THEN CAST(CONCAT(N'Fund ', COALESCE(NULLIF(u.[FundCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
            (CASE WHEN u.[AccountIncludeInReport] = 0 THEN CAST(CONCAT(N'account:', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
             CASE WHEN u.[AccountIncludeInReport] = 0 THEN CAST(CONCAT(N'Account ', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
            (CASE WHEN u.[AccountIncludeInReport] IS NULL THEN CAST(CONCAT(N'account:', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
             CASE WHEN u.[AccountIncludeInReport] IS NULL THEN CAST(CONCAT(N'Account ', COALESCE(NULLIF(u.[AccountCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
            (CASE WHEN u.[ActivityIncludeInReport] = 0 THEN CAST(CONCAT(N'activity:', COALESCE(NULLIF(u.[ActivityCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
             CASE WHEN u.[ActivityIncludeInReport] = 0 THEN CAST(CONCAT(N'Activity ', COALESCE(NULLIF(u.[ActivityCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
            (CASE WHEN u.[ActivityIncludeInReport] IS NULL THEN CAST(CONCAT(N'activity:', COALESCE(NULLIF(u.[ActivityCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
             CASE WHEN u.[ActivityIncludeInReport] IS NULL THEN CAST(CONCAT(N'Activity ', COALESCE(NULLIF(u.[ActivityCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END),
            (CASE WHEN COALESCE(u.[FundCode], N'') <> N'13U02' AND u.[PurposeIncludeInReport] = 0 THEN CAST(CONCAT(N'purpose:', COALESCE(NULLIF(u.[PurposeCode], N''), N'(blank)'), N':excluded') AS NVARCHAR(220)) END,
             CASE WHEN COALESCE(u.[FundCode], N'') <> N'13U02' AND u.[PurposeIncludeInReport] = 0 THEN CAST(CONCAT(N'Purpose ', COALESCE(NULLIF(u.[PurposeCode], N''), N'(blank)'), N' excluded') AS NVARCHAR(500)) END),
            (CASE WHEN COALESCE(u.[FundCode], N'') <> N'13U02' AND u.[PurposeIncludeInReport] IS NULL THEN CAST(CONCAT(N'purpose:', COALESCE(NULLIF(u.[PurposeCode], N''), N'(blank)'), N':unclassified') AS NVARCHAR(220)) END,
             CASE WHEN COALESCE(u.[FundCode], N'') <> N'13U02' AND u.[PurposeIncludeInReport] IS NULL THEN CAST(CONCAT(N'Purpose ', COALESCE(NULLIF(u.[PurposeCode], N''), N'(blank)'), N' unclassified') AS NVARCHAR(500)) END)
    ) reason([Code], [Label])
    WHERE reason.[Code] IS NOT NULL;

    DECLARE @factRowCount INT = (SELECT COUNT(1) FROM [data].[ExpenseReviewTransactionFacts] WHERE [CycleStart] = @cycleStart AND [CycleEnd] = @cycleEnd);
    DECLARE @reasonRowCount INT = (SELECT COUNT(1) FROM [data].[ExpenseReviewTransactionReasons] WHERE [CycleStart] = @cycleStart AND [CycleEnd] = @cycleEnd);

    INSERT INTO [data].[ExpenseReviewCacheStatus]
    (
        [CycleStart],
        [CycleEnd],
        [RefreshedAt],
        [FactRowCount],
        [ReasonRowCount]
    )
    VALUES
    (
        @cycleStart,
        @cycleEnd,
        SYSUTCDATETIME(),
        @factRowCount,
        @reasonRowCount
    );

    SELECT
        @factRowCount AS [FactRowCount],
        @reasonRowCount AS [ReasonRowCount],
        CAST(1 AS BIT) AS [Refreshed];

    COMMIT TRANSACTION;
END
