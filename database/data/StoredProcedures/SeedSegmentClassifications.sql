CREATE PROCEDURE [data].[SeedSegmentClassifications]
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert any segment value present in the imported transactions but missing
    -- from SegmentClassifications, as an unclassified row (IncludeInReport NULL).
    -- Existing rows and their classifications are never modified: unclassified
    -- fails closed downstream until someone classifies the code in step 2.
    --
    -- Descriptions come from the ChartSegments reference data where available.
    -- Ern codes (UCPath DOS/earnings codes) have no local description source;
    -- the UCPath import fills those in from the PeopleSoft earnings table.
    -- 'XXX' is the placeholder DOS code on fringe rows, which carry no FTE, so
    -- classifying it is meaningless and it is not seeded.

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
        SELECT 'Ern', [DosCode] FROM [data].[UcPathTransactions] WHERE [DosCode] IS NOT NULL AND [DosCode] <> 'XXX'
    )
    INSERT INTO [data].[SegmentClassifications] ([SegmentType], [Code], [Description])
    OUTPUT inserted.[SegmentType] INTO @inserted ([SegmentType])
    SELECT
        tv.SegmentType,
        tv.Code,
        LEFT(cs.[Description], 300)
    FROM TransactionValues tv
    LEFT JOIN [data].[ChartSegments] cs
        ON cs.[SegmentName] = tv.SegmentType AND cs.[Code] = tv.Code
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [data].[SegmentClassifications] existing
        WHERE existing.[SegmentType] = tv.SegmentType
          AND existing.[Code] = tv.Code
    );

    -- One row per segment type with the number of newly seeded codes
    -- (types with nothing new are omitted).
    SELECT
        CAST([SegmentType] AS NVARCHAR(20)) AS SegmentType,
        COUNT(*)                            AS InsertedCount
    FROM @inserted
    GROUP BY [SegmentType];
END
