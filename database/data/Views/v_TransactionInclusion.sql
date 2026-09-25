CREATE VIEW [data].[v_TransactionInclusion]
AS
-- The report inclusion rule, one row per imported transaction. This is the
-- single place the rule lives: Expense Review reads it to show Included and
-- the exclusion reasons, and BuildAutoAssociations reads it to pick the rows
-- that go into the expense summary. No cycle window here; consumers apply it.
--
-- Included = 1 when all of:
--   ExcludedByDate = 0 (NULL fails closed);
--   AE: AccountInUcPath = 0; UCPath: AccountNotInAE = 0 (NULL fails closed);
--   the financial department, fund, account and activity are classified
--   included (unclassified fails closed);
--   the purpose is classified included, or the fund is 13U02 (State
--   Appropriations are reported regardless of purpose);
--   an ExpenseSfn was derived (v_TransactionSfn);
--   not a UCPath row on account 531010 whose fund maps to 201, 202 or 205
--   (last year's summary carve-out).
--
-- ErnIncludeInReport is exposed but is not part of Included: an excluded ERN
-- code removes a UCPath row's FTE from totals, never its dollars.
WITH Transactions AS
(
    SELECT
        CAST(N'UCPath' AS NVARCHAR(6))                 AS [Source],
        CAST(u.[LaborTransactionId] AS NVARCHAR(125))  AS [TransactionId],
        u.[LaborTransactionId]                         AS [LaborTransactionId],
        CAST(NULL AS BIGINT)                           AS [AeTransactionId],
        u.[Fund],
        u.[FinancialDepartment],
        u.[Account],
        u.[Activity],
        u.[Purpose],
        u.[ErnCode],
        u.[ExcludedByDate],
        CAST(NULL AS BIT)                              AS [AccountInUcPath],
        u.[AccountNotInAE],
        s.[ExpenseSfn],
        s.[ExpenseSfnSource],
        s.[FteSfn]
    FROM [data].[UcPathTransactions] u
    LEFT JOIN [data].[v_TransactionSfn] s
        ON s.[Source] = N'UCPath' AND s.[LaborTransactionId] = u.[LaborTransactionId]

    UNION ALL

    SELECT
        CAST(N'AE' AS NVARCHAR(6))                     AS [Source],
        CAST(a.[Id] AS NVARCHAR(125))                  AS [TransactionId],
        CAST(NULL AS NVARCHAR(125))                    AS [LaborTransactionId],
        a.[Id]                                         AS [AeTransactionId],
        a.[Fund],
        a.[FinancialDepartment],
        a.[Account],
        a.[Activity],
        a.[Purpose],
        CAST(NULL AS NVARCHAR(3))                      AS [ErnCode],
        a.[ExcludedByDate],
        a.[AccountInUcPath],
        CAST(NULL AS BIT)                              AS [AccountNotInAE],
        s.[ExpenseSfn],
        s.[ExpenseSfnSource],
        s.[FteSfn]
    FROM [data].[AETransactions] a
    LEFT JOIN [data].[v_TransactionSfn] s
        ON s.[Source] = N'AE' AND s.[AeTransactionId] = a.[Id]
),
Classified AS
(
    SELECT
        t.*,
        fd.[IncludeInReport] AS [FinancialDeptIncludeInReport],
        fu.[IncludeInReport] AS [FundIncludeInReport],
        ac.[IncludeInReport] AS [AccountIncludeInReport],
        av.[IncludeInReport] AS [ActivityIncludeInReport],
        pu.[IncludeInReport] AS [PurposeIncludeInReport],
        er.[IncludeInReport] AS [ErnIncludeInReport],
        CAST(CASE
            WHEN t.[Source] = N'UCPath'
             AND t.[Account] = '531010'
             AND t.[ExpenseSfn] IN ('201', '202', '205')
            THEN 1 ELSE 0
        END AS BIT) AS [Account531010OnHatchFund]
    FROM Transactions t
    LEFT JOIN [data].[SegmentClassifications] fd
        ON fd.[SegmentType] = 'FinancialDepartment' AND fd.[Code] = t.[FinancialDepartment]
    LEFT JOIN [data].[SegmentClassifications] fu
        ON fu.[SegmentType] = 'Fund' AND fu.[Code] = t.[Fund]
    LEFT JOIN [data].[SegmentClassifications] ac
        ON ac.[SegmentType] = 'Account' AND ac.[Code] = t.[Account]
    LEFT JOIN [data].[SegmentClassifications] av
        ON av.[SegmentType] = 'Activity' AND av.[Code] = t.[Activity]
    LEFT JOIN [data].[SegmentClassifications] pu
        ON pu.[SegmentType] = 'Purpose' AND pu.[Code] = t.[Purpose]
    LEFT JOIN [data].[SegmentClassifications] er
        ON er.[SegmentType] = 'Ern' AND er.[Code] = t.[ErnCode]
)
SELECT
    c.[Source],
    c.[TransactionId],
    c.[LaborTransactionId],
    c.[AeTransactionId],
    c.[ExcludedByDate],
    c.[AccountInUcPath],
    c.[AccountNotInAE],
    c.[FinancialDeptIncludeInReport],
    c.[FundIncludeInReport],
    c.[AccountIncludeInReport],
    c.[ActivityIncludeInReport],
    c.[PurposeIncludeInReport],
    c.[ErnIncludeInReport],
    c.[ExpenseSfn],
    c.[ExpenseSfnSource],
    c.[FteSfn],
    c.[Account531010OnHatchFund],
    CAST(CASE
        WHEN c.[ExcludedByDate] = 0
         AND ((c.[Source] = N'AE' AND c.[AccountInUcPath] = 0)
           OR (c.[Source] = N'UCPath' AND c.[AccountNotInAE] = 0))
         AND c.[ExpenseSfn] IS NOT NULL
         -- TODO: Seek stakeholder review on this fail-closed null/missing classification behavior.
         AND COALESCE(c.[FinancialDeptIncludeInReport], 0) = 1
         AND COALESCE(c.[FundIncludeInReport], 0) = 1
         AND COALESCE(c.[AccountIncludeInReport], 0) = 1
         AND COALESCE(c.[ActivityIncludeInReport], 0) = 1
         AND (c.[Fund] = '13U02' OR COALESCE(c.[PurposeIncludeInReport], 0) = 1)
         AND c.[Account531010OnHatchFund] = 0
        THEN 1 ELSE 0
    END AS BIT) AS [Included]
FROM Classified c;
