CREATE PROCEDURE [data].[SeedSegmentClassifications]
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert any segment value present in the imported transactions but missing
    -- from SegmentClassifications, as an unclassified row (IncludeInReport NULL).
    -- Existing rows and their classifications are never modified: unclassified
    -- fails closed downstream until someone classifies the code in step 2.
    --
    -- Descriptions come from the ChartSegments reference data where available;
    -- ERN descriptions come from the imported UcPathTransactions rows, which
    -- carry UC_EARNCD_DESCR from the salary view. Existing Ern rows with a
    -- NULL description are backfilled the same way (a description is metadata,
    -- not a classification). 'XXX' is the placeholder ERN code on fringe rows,
    -- which carry no FTE, so classifying it is meaningless and it is not
    -- seeded.

    DECLARE @inserted TABLE ([SegmentType] NVARCHAR(20) NOT NULL);

    WITH TransactionValues AS
    (
        SELECT 'Fund' AS SegmentType, [Fund] AS Code FROM [data].[AETransactions] WHERE [Fund] IS NOT NULL
        UNION
        SELECT 'Fund', [Fund] FROM [data].[UcPathTransactions] WHERE [Fund] IS NOT NULL
        UNION
        SELECT 'Account', [Account] FROM [data].[AETransactions] WHERE [Account] IS NOT NULL
        UNION
        SELECT 'Account', [Account] FROM [data].[UcPathTransactions] WHERE [Account] IS NOT NULL
        UNION
        SELECT 'FinancialDepartment', [FinancialDepartment] FROM [data].[AETransactions] WHERE [FinancialDepartment] IS NOT NULL
        UNION
        SELECT 'FinancialDepartment', [FinancialDepartment] FROM [data].[UcPathTransactions] WHERE [FinancialDepartment] IS NOT NULL
        UNION
        SELECT 'Activity', [Activity] FROM [data].[AETransactions] WHERE [Activity] IS NOT NULL
        UNION
        SELECT 'Activity', [Activity] FROM [data].[UcPathTransactions] WHERE [Activity] IS NOT NULL
        UNION
        SELECT 'Purpose', [Purpose] FROM [data].[AETransactions] WHERE [Purpose] IS NOT NULL
        UNION
        SELECT 'Purpose', [Purpose] FROM [data].[UcPathTransactions] WHERE [Purpose] IS NOT NULL
        UNION
        SELECT 'Ern', [ErnCode] FROM [data].[UcPathTransactions] WHERE [ErnCode] <> 'XXX'
    )
    INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description])
    OUTPUT inserted.[SegmentType] INTO @inserted ([SegmentType])
    SELECT
        tv.SegmentType,
        tv.Code,
        LEFT(COALESCE(cs.[Description], ern.[Description]), 300)
    FROM TransactionValues tv
    LEFT JOIN [data].[ChartSegments] cs
        ON cs.[SegmentName] = tv.SegmentType AND cs.[Code] = tv.Code
    LEFT JOIN
    (
        SELECT [ErnCode], MAX([ErnDescription]) AS [Description]
        FROM [data].[UcPathTransactions]
        WHERE [ErnDescription] IS NOT NULL
        GROUP BY [ErnCode]
    ) ern
        ON tv.SegmentType = 'Ern' AND ern.[ErnCode] = tv.Code
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [data].[SegmentClassifications] existing
        WHERE existing.[SegmentType] = tv.SegmentType
          AND existing.[Code] = tv.Code
    );

    -- Backfill descriptions on Ern rows seeded before their description was
    -- available (for example a code first seen on rows imported after the
    -- code itself was seeded).
    UPDATE sc
    SET sc.[Description] = LEFT(ern.[Description], 300)
    FROM [data].[SegmentClassifications] sc
    JOIN
    (
        SELECT [ErnCode], MAX([ErnDescription]) AS [Description]
        FROM [data].[UcPathTransactions]
        WHERE [ErnDescription] IS NOT NULL
        GROUP BY [ErnCode]
    ) ern
        ON ern.[ErnCode] = sc.[Code]
    WHERE sc.[SegmentType] = 'Ern' AND sc.[Description] IS NULL;

    -- One row per segment type with the number of newly seeded codes
    -- (types with nothing new are omitted).
    SELECT
        CAST([SegmentType] AS NVARCHAR(20)) AS SegmentType,
        COUNT(*)                            AS InsertedCount
    FROM @inserted
    GROUP BY [SegmentType];
END
