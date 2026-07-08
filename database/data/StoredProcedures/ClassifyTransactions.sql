CREATE PROCEDURE [data].[ClassifyTransactions]
    @cycleStart DATE,
    @cycleEnd   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Stamps the persisted exclusion columns on the imported transactions: the
    -- rules step 2 classification does not own. Step 2 based exclusions (fund,
    -- account, financial dept, activity, ern) are derived at read time from
    -- SegmentClassifications and are never stamped here.

    IF @cycleStart IS NULL OR @cycleEnd IS NULL
        THROW 50000, '@cycleStart and @cycleEnd are required.', 1;

    IF @cycleStart > @cycleEnd
        THROW 50000, '@cycleStart must not be after @cycleEnd.', 1;

    -- AccountNotInAE compares against the AE chart of accounts; an empty
    -- reference table would flag every UCPath row, so fail loudly instead.
    IF NOT EXISTS (SELECT 1 FROM [data].[ChartSegments] WHERE [SegmentName] = 'Account')
        THROW 50000, 'ChartSegments has no Account rows; run the segment reference import first.', 1;

    IF NOT EXISTS (SELECT 1 FROM [data].[Projects])
        THROW 50000, 'Projects is empty; run BuildProjects first.', 1;

    -- SFN mismatches on 204 projects are resolved during Project Identification
    -- (GetProjectList reports them); none should remain by import time.
    IF EXISTS
    (
        SELECT 1 FROM [data].[Projects]
        WHERE [PgmSfnBucket] IS NOT NULL
          AND (
                ([NifaSfn] =  '204' AND [PgmSfnBucket] <> '204')
             OR ([NifaSfn] <> '204' AND [PgmSfnBucket] =  '204')
              )
    )
        THROW 50000, 'Projects has 204 SFN disagreements between NIFA and PGM; resolve them in Project Identification first.', 1;

    -- AE projects mapped to a 204 NIFA project. Rows on these projects are
    -- reportable regardless of purpose (the 204 carve-out). Any reportable 204
    -- project is mapped through ActiveProjects/AllProjects by the time the
    -- import runs, so the materialized project list is the complete source.
    SELECT DISTINCT [AEProjectNumber]
    INTO #Projects204
    FROM [data].[Projects]
    WHERE [NifaSfn] = '204'
      AND [AEProjectNumber] IS NOT NULL;

    CREATE UNIQUE CLUSTERED INDEX [IX_Projects204] ON #Projects204 ([AEProjectNumber]);

    -- ExcludedByDate, AE: by accounting period membership, consistent with how
    -- the rows are pulled (period_name list). The cycle months are generated as
    -- period names ('Oct-24' style, culture pinned) the same way the import
    -- builds its pull list; a row is in the cycle iff its period is in this
    -- set, so buffer periods and NULLs are excluded by date.
    DECLARE @cyclePeriods TABLE ([PeriodName] NVARCHAR(30) PRIMARY KEY);

    DECLARE @month DATE = DATEFROMPARTS(YEAR(@cycleStart), MONTH(@cycleStart), 1);
    WHILE @month <= @cycleEnd
    BEGIN
        INSERT INTO @cyclePeriods VALUES (FORMAT(@month, 'MMM-yy', 'en-US'));
        SET @month = DATEADD(MONTH, 1, @month);
    END;

    UPDATE t
    SET [ExcludedByDate] = CASE WHEN cp.[PeriodName] IS NULL THEN 1 ELSE 0 END
    FROM [data].[AETransactions] t
    LEFT JOIN @cyclePeriods cp ON cp.[PeriodName] = t.[PeriodName];

    -- ExcludedByDate, UCPath: by pay period end date (authoritative; fiscal
    -- year/period are unreliable on payroll corrections). Missing dates fail
    -- closed as excluded.
    UPDATE [data].[UcPathTransactions]
    SET [ExcludedByDate] =
        CASE
            WHEN [PayPeriodEndDate] IS NULL                                         THEN 1
            WHEN CAST([PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd THEN 0
            ELSE 1
        END;

    -- ExcludedByPurpose: hardcoded 2025 list, with carve-outs for fund 13U02
    -- (state AES funds, reported regardless of purpose) and 204 projects.
    UPDATE t
    SET [ExcludedByPurpose] =
        CASE
            WHEN t.[Purpose] IN ('00', '40', '43', '60', '61', '62', '72', '76', '78', '80')
                 AND ISNULL(t.[Fund], '') <> '13U02'
                 AND p204.[AEProjectNumber] IS NULL
            THEN 1
            ELSE 0
        END
    FROM [data].[AETransactions] t
    LEFT JOIN #Projects204 p204 ON p204.[AEProjectNumber] = t.[Project];

    UPDATE t
    SET [ExcludedByPurpose] =
        CASE
            WHEN t.[Purpose] IN ('00', '40', '43', '60', '61', '62', '72', '76', '78', '80')
                 AND ISNULL(t.[Fund], '') <> '13U02'
                 AND p204.[AEProjectNumber] IS NULL
            THEN 1
            ELSE 0
        END
    FROM [data].[UcPathTransactions] t
    LEFT JOIN #Projects204 p204 ON p204.[AEProjectNumber] = t.[Project];

    -- AccountNotInAE: UCPath accounts that do not exist in the AE chart of
    -- accounts (this should not happen but does). Missing accounts fail closed.
    UPDATE t
    SET [AccountNotInAE] =
        CASE
            WHEN t.[Account] IS NULL THEN 1
            WHEN cs.[Code] IS NULL   THEN 1
            ELSE 0
        END
    FROM [data].[UcPathTransactions] t
    LEFT JOIN [data].[ChartSegments] cs
        ON cs.[SegmentName] = 'Account' AND cs.[Code] = t.[Account];

    -- Row counts for the import run stage.
    SELECT
        (SELECT COUNT(*) FROM [data].[AETransactions])     AS AeRowsClassified,
        (SELECT COUNT(*) FROM [data].[UcPathTransactions]) AS UcPathRowsClassified;
END
