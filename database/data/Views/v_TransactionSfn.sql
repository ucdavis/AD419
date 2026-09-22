CREATE VIEW [data].[v_TransactionSfn]
AS
-- ExpenseSFN and FTESFN per imported transaction, derived at read time. This
-- is the single place the derivation lives; Expense Review inclusion, the
-- expense summary, and the auto-association rules read from here. Inclusion
-- is not applied; consumers filter included rows.
--
-- ExpenseSfn, first match wins, for both sources:
--   1. Fund 13U02 is State Appropriations (220) regardless of anything else.
--      The fund's own classified SFN is deliberately ignored for 13U02;
--      Expense Review's purpose exception for 13U02 lives in
--      ExpenseReviewService.UnifiedTransactionsCte and must stay in step
--      with this rule.
--   2. The fund's classified SFN when it is a concrete line.
--   3. When the fund is classified 'Multiple', the AE project decides: the
--      cycle project list (data.Projects) when every NIFA project the AE
--      project maps to agrees on a line (UNKNOWN rows do not count), otherwise
--      the PGM award's ALN derived line (v_PgmProjectSfnBuckets.PgmSfn) when
--      every award row agrees. An UNKNOWN row (or a NULL PgmSfn award) is not
--      a dissenting vote: it is dropped before the agreement check, so one
--      UNKNOWN row plus one 204 row resolves to 204.
--   4. Otherwise NULL. Unclassified funds, funds with no SFN, and 'Multiple'
--      funds on unmapped projects all land here and are excluded downstream.
--
-- FteSfn: UCPath rows only. JobCode to Titles to StaffTypes.FteSfn; any
-- missing link is NULL. Fringe rows carry the backfilled job code so they
-- resolve like their salary rows. AE rows are always NULL.
--
-- LaborTransactionId and AeTransactionId carry the native keys so consumers
-- can join on an indexed column; TransactionId is the text form shared with
-- v_TransactionOrgR.
--
-- ExpenseSfnSource has no consumer yet; the auto-association build (#76)
-- will read it.
WITH FundSfn AS
(
    SELECT [Code] AS [Fund], [Sfn]
    FROM [data].[SegmentClassifications]
    WHERE [SegmentType] = 'Fund'
),
ProjectListSfn AS
(
    SELECT [AEProjectNumber], MIN([Sfn]) AS [Sfn]
    FROM [data].[Projects]
    WHERE [AEProjectNumber] IS NOT NULL
      AND [Sfn] <> 'UNKNOWN'
    GROUP BY [AEProjectNumber]
    HAVING COUNT(DISTINCT [Sfn]) = 1
),
PgmAwardSfn AS
(
    SELECT [ProjectNumber], MIN([PgmSfn]) AS [Sfn]
    FROM [data].[v_PgmProjectSfnBuckets]
    WHERE [ProjectNumber] IS NOT NULL
      AND [PgmSfn] IS NOT NULL
    GROUP BY [ProjectNumber]
    HAVING COUNT(DISTINCT [PgmSfn]) = 1
),
Transactions AS
(
    SELECT
        CAST(N'UCPath' AS NVARCHAR(6)) AS [Source],
        CAST(u.[LaborTransactionId] AS NVARCHAR(125)) AS [TransactionId],
        u.[LaborTransactionId] AS [LaborTransactionId], CAST(NULL AS BIGINT) AS [AeTransactionId],
        u.[Fund],
        u.[Project],
        u.[JobCode]
    FROM [data].[UcPathTransactions] u

    UNION ALL

    SELECT
        CAST(N'AE' AS NVARCHAR(6)) AS [Source],
        CAST(a.[Id] AS NVARCHAR(125)) AS [TransactionId],
        CAST(NULL AS NVARCHAR(125)) AS [LaborTransactionId], a.[Id] AS [AeTransactionId],
        a.[Fund],
        a.[Project],
        CAST(NULL AS NVARCHAR(4)) AS [JobCode]
    FROM [data].[AETransactions] a
)
SELECT
    t.[Source],
    t.[TransactionId],
    t.[LaborTransactionId],
    t.[AeTransactionId],
    CAST(CASE
        WHEN t.[Fund] = '13U02'                              THEN '220'
        WHEN fs.[Sfn] IS NOT NULL AND fs.[Sfn] <> 'Multiple' THEN fs.[Sfn]
        WHEN fs.[Sfn] = 'Multiple'                           THEN COALESCE(pl.[Sfn], pa.[Sfn])
        ELSE NULL
    END AS NVARCHAR(10)) AS [ExpenseSfn],
    CAST(CASE
        WHEN t.[Fund] = '13U02'                              THEN N'Fund13U02'
        WHEN fs.[Sfn] IS NOT NULL AND fs.[Sfn] <> 'Multiple' THEN N'FundClassification'
        WHEN fs.[Sfn] = 'Multiple' AND pl.[Sfn] IS NOT NULL  THEN N'ProjectList'
        WHEN fs.[Sfn] = 'Multiple' AND pa.[Sfn] IS NOT NULL  THEN N'PgmAward'
        ELSE NULL
    END AS NVARCHAR(20)) AS [ExpenseSfnSource],
    CAST(CASE WHEN t.[Source] = N'UCPath' THEN st.[FteSfn] END AS NVARCHAR(10)) AS [FteSfn]
FROM Transactions t
LEFT JOIN FundSfn fs
    ON fs.[Fund] = t.[Fund]
LEFT JOIN ProjectListSfn pl
    ON pl.[AEProjectNumber] = t.[Project]
LEFT JOIN PgmAwardSfn pa
    ON pa.[ProjectNumber] = t.[Project]
LEFT JOIN [data].[Titles] ti
    ON t.[Source] = N'UCPath' AND ti.[TitleCode] = t.[JobCode]
LEFT JOIN [data].[StaffTypes] st
    ON st.[StaffTypeCode] = ti.[StaffTypeCode];
