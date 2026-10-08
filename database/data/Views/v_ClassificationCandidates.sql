CREATE VIEW [data].[v_ClassificationCandidates]
AS
-- The chart-string codes worth classifying in Data Classification: a code is
-- a candidate when at least one imported transaction carries it and that
-- transaction passes every report rule except the code's own classification.
-- Codes whose transactions are all excluded anyway (by date, the AE/UCPath
-- account overlap, a missing or off-list 204 expense SFN, or an excluded
-- financial department, account or purpose) cannot change the report, so they are
-- left out of the classification list and do not block the stage.
--
-- Rules, read from v_TransactionInclusion so they stay in step with it:
--   every row: ExcludedByDate = 0, and AccountInUcPath = 0 (AE) or
--   AccountNotInAE = 0 (UCPath);
--   SFN: ExpenseSfn is set, and neither the 531010 carve-out nor the
--   off-list 204 rule (Sfn204NotOnProjectList) applies. An unclassified
--   fund passes: only a classification of "no" hides other codes, and
--   otherwise an excluded department on a blank fund would hide both, with
--   neither reachable from the grid. Skipped for Fund codes, because a
--   fund's own classification is what sets its SFN;
--   gates: financial department, account and purpose are not classified
--   excluded (blank passes, so the gates can be classified in any order);
--   purpose passes on PurposeExempt rows (13U02, 204 projects), and purpose
--   codes are only candidates on rows that are not exempt.
-- Fund, activity and ERN classifications never hide other codes. ERN codes
-- come from UCPath rows only.
WITH Rows AS
(
    SELECT
        i.[Source],
        i.[Fund],
        i.[FinancialDepartment],
        i.[Account],
        i.[Activity],
        i.[Purpose],
        i.[ErnCode],
        i.[PurposeExempt],
        CASE
            WHEN i.[FundIncludeInReport] IS NULL THEN 1
            WHEN i.[ExpenseSfn] IS NOT NULL AND i.[Account531010OnHatchFund] = 0 AND i.[Sfn204NotOnProjectList] = 0 THEN 1
            ELSE 0
        END AS [SfnOk],
        CASE WHEN COALESCE(i.[FinancialDeptIncludeInReport], 1) = 1 THEN 1 ELSE 0 END AS [DeptOk],
        CASE WHEN COALESCE(i.[AccountIncludeInReport], 1) = 1 THEN 1 ELSE 0 END AS [AccountOk],
        CASE WHEN i.[PurposeExempt] = 1 OR COALESCE(i.[PurposeIncludeInReport], 1) = 1 THEN 1 ELSE 0 END AS [PurposeOk]
    FROM [data].[v_TransactionInclusion] i
    WHERE i.[ExcludedByDate] = 0
      AND ((i.[Source] = N'AE' AND i.[AccountInUcPath] = 0)
        OR (i.[Source] = N'UCPath' AND i.[AccountNotInAE] = 0))
)
SELECT DISTINCT
    CAST(c.[SegmentType] AS NVARCHAR(20)) AS [SegmentType],
    CAST(c.[Code] AS NVARCHAR(50))        AS [Code]
FROM Rows r
CROSS APPLY
(
    VALUES
        ('FinancialDepartment', r.[FinancialDepartment],
            CASE WHEN r.[SfnOk] = 1 AND r.[AccountOk] = 1 AND r.[PurposeOk] = 1 THEN 1 ELSE 0 END),
        ('Account', r.[Account],
            CASE WHEN r.[SfnOk] = 1 AND r.[DeptOk] = 1 AND r.[PurposeOk] = 1 THEN 1 ELSE 0 END),
        ('Purpose', r.[Purpose],
            CASE WHEN r.[PurposeExempt] = 0 AND r.[SfnOk] = 1 AND r.[DeptOk] = 1 AND r.[AccountOk] = 1 THEN 1 ELSE 0 END),
        ('Fund', r.[Fund],
            CASE WHEN r.[DeptOk] = 1 AND r.[AccountOk] = 1 AND r.[PurposeOk] = 1 THEN 1 ELSE 0 END),
        ('Activity', r.[Activity],
            CASE WHEN r.[SfnOk] = 1 AND r.[DeptOk] = 1 AND r.[AccountOk] = 1 AND r.[PurposeOk] = 1 THEN 1 ELSE 0 END),
        ('Ern', r.[ErnCode],
            CASE WHEN r.[Source] = N'UCPath' AND r.[SfnOk] = 1 AND r.[DeptOk] = 1 AND r.[AccountOk] = 1 AND r.[PurposeOk] = 1 THEN 1 ELSE 0 END)
) c ([SegmentType], [Code], [Eligible])
WHERE c.[Eligible] = 1
  AND c.[Code] IS NOT NULL;
