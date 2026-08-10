CREATE PROCEDURE [data].[ClassifyTransactions]
    @cycleStart DATE,
    @cycleEnd   DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Stamps the persisted exclusion columns on the imported transactions: the
    -- rules step 2 classification does not own. Step 2 based exclusions (fund,
    -- account, financial dept, activity, ern, purpose) are derived at read time
    -- from SegmentClassifications and are never stamped here.

    IF @cycleStart IS NULL OR @cycleEnd IS NULL
        THROW 50000, '@cycleStart and @cycleEnd are required.', 1;

    IF @cycleStart > @cycleEnd
        THROW 50000, '@cycleStart must not be after @cycleEnd.', 1;

    -- AccountNotInAE compares against the AE chart of accounts; an empty
    -- reference table would flag every UCPath row, so fail loudly instead.
    IF NOT EXISTS (SELECT 1 FROM [data].[ChartSegments] WHERE [SegmentName] = 'Account')
        THROW 50000, 'ChartSegments has no Account rows; run the segment reference import first.', 1;

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
    -- year/period are unreliable on payroll corrections).
    UPDATE [data].[UcPathTransactions]
    SET [ExcludedByDate] =
        CASE
            WHEN CAST([PayPeriodEndDate] AS DATE) BETWEEN @cycleStart AND @cycleEnd THEN 0
            ELSE 1
        END;

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

    -- AccountInUcPath, AE: accounts that also appear in the UCPath pull. Those
    -- dollars are reported from payroll detail, so the AE rows are excluded to
    -- avoid double counting (2025 deleted them; a flag keeps them reviewable).
    UPDATE t
    SET [AccountInUcPath] =
        CASE
            WHEN t.[Account] IS NULL THEN 0
            WHEN EXISTS
            (
                SELECT 1 FROM [data].[UcPathTransactions] u
                WHERE u.[Account] = t.[Account]
            ) THEN 1
            ELSE 0
        END
    FROM [data].[AETransactions] t;

    -- Row counts for the import run stage.
    SELECT
        (SELECT COUNT(*) FROM [data].[AETransactions])     AS AeRowsClassified,
        (SELECT COUNT(*) FROM [data].[UcPathTransactions]) AS UcPathRowsClassified;
END
