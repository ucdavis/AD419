CREATE PROCEDURE [data].[BuildAutoAssociations]
    @cycleStart DATE,
    @cycleEnd   DATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Any failure rolls back the whole build so staging is never half built.
    SET XACT_ABORT ON;

    -- Builds the expense summary and the staged auto-associations for the
    -- current cycle, replacing whatever was there. Called when OrgR Review
    -- completes; cleared when an upstream stage reopens (AutoAssociationBuilder).

    IF @cycleStart IS NULL OR @cycleEnd IS NULL
        THROW 50000, '@cycleStart and @cycleEnd are required.', 1;
    IF @cycleStart > @cycleEnd
        THROW 50000, '@cycleStart must not be after @cycleEnd.', 1;
    IF NOT EXISTS (SELECT 1 FROM [data].[Projects])
        THROW 50000, 'Projects is empty; run the Data Import before building auto-associations.', 1;

    BEGIN TRAN;

    DELETE FROM [data].[StagedAssociations];
    DELETE FROM [data].[AutoAssociationExcludedProjects];
    DELETE FROM [data].[ExpenseSummary];
    DELETE FROM [data].[AutoAssociationBuilds];

    -- Included transactions in the cycle window, grouped like last year's
    -- ad419_Transactions_Summary. A UCPath row's FTE counts only when its ERN
    -- code is classified included (dollars always count). AE rows carry no FTE.
    IF EXISTS
    (
        SELECT 1
        FROM [data].[AETransactions] a
        JOIN [data].[v_TransactionInclusion] i ON i.[Source] = N'AE' AND i.[AeTransactionId] = a.[Id]
        LEFT JOIN [data].[v_TransactionOrgR] o ON o.[Source] = N'AE' AND o.[TransactionId] = CAST(a.[Id] AS NVARCHAR(125))
        WHERE i.[Included] = 1
          AND TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) BETWEEN @cycleStart AND @cycleEnd
          AND o.[OrgR] IS NULL
        UNION ALL
        SELECT 1
        FROM [data].[UcPathTransactions] u
        JOIN [data].[v_TransactionInclusion] i ON i.[Source] = N'UCPath' AND i.[LaborTransactionId] = u.[LaborTransactionId]
        LEFT JOIN [data].[v_TransactionOrgR] o ON o.[Source] = N'UCPath' AND o.[TransactionId] = u.[LaborTransactionId]
        WHERE i.[Included] = 1
          AND CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
          AND o.[OrgR] IS NULL
    )
        THROW 50000, 'An included transaction has no OrgR; complete the OrgR Review mappings first.', 1;

    INSERT INTO [data].[ExpenseSummary]
        ([Source], [OrgR], [Entity], [Project], [Activity], [Fund], [FinancialDepartment],
         [EmployeeId], [EmployeeName], [JobCode], [ExpenseSfn], [FteSfn], [Expenses], [Fte])
    SELECT
        x.[Source], x.[OrgR], x.[Entity], x.[Project], x.[Activity], x.[Fund], x.[FinancialDepartment],
        x.[EmployeeId], x.[EmployeeName], x.[JobCode], x.[ExpenseSfn], x.[FteSfn],
        SUM(x.[Amount]), SUM(x.[Fte])
    FROM
    (
        SELECT
            CAST(N'AE' AS NVARCHAR(12)) AS [Source], o.[OrgR], a.[Entity], a.[Project], a.[Activity], a.[Fund], a.[FinancialDepartment],
            CAST(NULL AS NVARCHAR(10)) AS [EmployeeId], CAST(NULL AS NVARCHAR(100)) AS [EmployeeName], CAST(NULL AS NVARCHAR(4)) AS [JobCode],
            i.[ExpenseSfn], i.[FteSfn],
            COALESCE(a.[Amount], 0) AS [Amount], CAST(0 AS DECIMAL(9, 6)) AS [Fte]
        FROM [data].[AETransactions] a
        JOIN [data].[v_TransactionInclusion] i ON i.[Source] = N'AE' AND i.[AeTransactionId] = a.[Id]
        JOIN [data].[v_TransactionOrgR] o ON o.[Source] = N'AE' AND o.[TransactionId] = CAST(a.[Id] AS NVARCHAR(125))
        WHERE i.[Included] = 1
          AND TRY_CONVERT(DATE, CONCAT('01-', a.[PeriodName]), 6) BETWEEN @cycleStart AND @cycleEnd

        UNION ALL

        SELECT
            CAST(N'UCPath' AS NVARCHAR(12)), o.[OrgR], u.[Entity], u.[Project], u.[Activity], u.[Fund], u.[FinancialDepartment],
            u.[EmployeeId], u.[EmployeeName], u.[JobCode],
            i.[ExpenseSfn], i.[FteSfn],
            u.[Amount], CASE WHEN i.[ErnIncludeInReport] = 1 THEN u.[CalculatedFte] ELSE CAST(0 AS DECIMAL(9, 6)) END
        FROM [data].[UcPathTransactions] u
        JOIN [data].[v_TransactionInclusion] i ON i.[Source] = N'UCPath' AND i.[LaborTransactionId] = u.[LaborTransactionId]
        JOIN [data].[v_TransactionOrgR] o ON o.[Source] = N'UCPath' AND o.[TransactionId] = u.[LaborTransactionId]
        WHERE i.[Included] = 1
          AND CAST(u.[PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd
    ) x
    GROUP BY x.[Source], x.[OrgR], x.[Entity], x.[Project], x.[Activity], x.[Fund], x.[FinancialDepartment],
             x.[EmployeeId], x.[EmployeeName], x.[JobCode], x.[ExpenseSfn], x.[FteSfn]
    HAVING SUM(x.[Amount]) <> 0;

    -- Field Station and CE Specialist uploads become synthetic summary rows
    -- that associate whole to their accession (rules FS and CE).
    INSERT INTO [data].[ExpenseSummary]
        ([Source], [OrgR], [AccessionNumber], [ExpenseSfn], [FteSfn], [Expenses], [Fte])
    SELECT N'FieldStation', N'FS', fs.[ProjectAccessionNum], N'22F', N'241', fs.[FieldStationCharge], 0
    FROM [data].[ad419_FieldStationExpenses] fs
    WHERE EXISTS (SELECT 1 FROM [data].[Projects] p WHERE p.[AccessionNumber] = fs.[ProjectAccessionNum]);

    INSERT INTO [data].[ExpenseSummary]
        ([Source], [OrgR], [EmployeeId], [PiName], [AccessionNumber], [ExpenseSfn], [FteSfn], [Expenses], [Fte])
    SELECT N'CE', ce.[DeptLevelOrg], ce.[EmployeeId], ce.[Pi], ce.[ProjectAccessionNum], ce.[Exp SFN], ce.[FTE SFN],
           ce.[FullAnnualPayRate] * ce.[FTE] * ce.[PercentCeEffort], ce.[PercentCeEffort] * ce.[FTE]
    FROM [data].[ad419_CESpecialists] ce
    WHERE EXISTS (SELECT 1 FROM [data].[Projects] p WHERE p.[AccessionNumber] = ce.[ProjectAccessionNum]);

    -- A 204 expense whose AE project is not on any 204 NIFA project cannot be
    -- associated; it is kept for the read-only report and skipped by the rules.
    UPDATE s
    SET [RuleExclusion] = N'Misclassified204'
    FROM [data].[ExpenseSummary] s
    WHERE s.[Source] IN (N'AE', N'UCPath')
      AND s.[ExpenseSfn] = '204'
      AND NOT EXISTS
      (
          SELECT 1 FROM [data].[Projects] p
          WHERE p.[Sfn] = '204' AND p.[AEProjectNumber] = s.[Project]
      );

    -- Dry run against every project: projects whose total would be under $100
    -- are excluded so proration does not scatter dollars onto tiny projects.
    -- Projects is at NIFA x AE grain; collapse to one row per accession so shares are not counted once per AE project.
    INSERT INTO [data].[AutoAssociationExcludedProjects] ([AccessionNumber], [NifaProjectNumber], [Total])
    SELECT c.[AccessionNumber], MIN(p.[NifaProjectNumber]), SUM(c.[Expenses])
    FROM [data].[AutoAssociationCandidates]() c
    JOIN (SELECT DISTINCT [AccessionNumber], [NifaProjectNumber] FROM [data].[Projects]) p
        ON p.[AccessionNumber] = c.[AccessionNumber]
    GROUP BY c.[AccessionNumber]
    HAVING SUM(c.[Expenses]) < 100;

    -- Real run: the function now skips the excluded projects, and shares are
    -- recomputed over the survivors.
    INSERT INTO [data].[StagedAssociations]
        ([ExpenseId], [Rule], [OrgR], [AeProject], [AccessionNumber], [ExpenseSfn], [Expenses], [Fte], [FteSfn])
    SELECT [ExpenseId], [Rule], [OrgR], [AeProject], [AccessionNumber], [ExpenseSfn], [Expenses], [Fte], [FteSfn]
    FROM [data].[AutoAssociationCandidates]();

    INSERT INTO [data].[AutoAssociationBuilds]
        ([CycleStart], [CycleEnd], [SummaryRows], [AssociationRows], [ExcludedProjects], [Misclassified204Rows])
    SELECT
        @cycleStart,
        @cycleEnd,
        (SELECT COUNT(*) FROM [data].[ExpenseSummary]),
        (SELECT COUNT(*) FROM [data].[StagedAssociations]),
        (SELECT COUNT(*) FROM [data].[AutoAssociationExcludedProjects]),
        (SELECT COUNT(*) FROM [data].[ExpenseSummary] WHERE [RuleExclusion] = N'Misclassified204');

    COMMIT;

    SELECT [BuildId], [SummaryRows], [AssociationRows], [ExcludedProjects], [Misclassified204Rows]
    FROM [data].[AutoAssociationBuilds];
END
