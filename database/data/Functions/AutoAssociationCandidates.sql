CREATE FUNCTION [data].[AutoAssociationCandidates]()
RETURNS TABLE
AS
RETURN
(
    -- Every association the rules would make from the current ExpenseSummary
    -- against the eligible projects: the cycle project list minus
    -- AutoAssociationExcludedProjects. BuildAutoAssociations calls this twice:
    -- once with the excluded table empty (dry run, to find projects whose total
    -- would be under $100) and once for real. Rules run in order; an expense
    -- taken by an earlier rule is skipped by later ones. Summary rows with a
    -- RuleExclusion never participate. The NOT EXISTS chain between rules is
    -- defensive: v_TransactionSfn gives fund 13U02 an unconditional 220, so a
    -- row can never qualify for both 204 and 220.
    WITH Eligible AS
    (
        SELECT p.[AccessionNumber], p.[UcpEmployeeId], p.[Sfn], p.[AEProjectNumber]
        FROM [data].[Projects] p
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [data].[AutoAssociationExcludedProjects] x
            WHERE x.[AccessionNumber] = p.[AccessionNumber]
        )
    ),
    Summary AS
    (
        SELECT * FROM [data].[ExpenseSummary] WHERE [RuleExclusion] IS NULL
    ),
    -- Rule 204: expense on a 204 AE project goes to that project's NIFA
    -- project(s). One AE project on several NIFA projects is split equally.
    Projects204 AS
    (
        SELECT e.[AEProjectNumber], e.[AccessionNumber],
               COUNT(*) OVER (PARTITION BY e.[AEProjectNumber]) AS [AccessionCount]
        FROM (SELECT DISTINCT [AEProjectNumber], [AccessionNumber] FROM Eligible WHERE [Sfn] = '204' AND [AEProjectNumber] IS NOT NULL) e
    ),
    Rule204 AS
    (
        SELECT s.[ExpenseId], CAST(N'204' AS NVARCHAR(10)) AS [Rule], s.[OrgR], s.[Project] AS [AeProject], m.[AccessionNumber],
               s.[ExpenseSfn], s.[Expenses] / m.[AccessionCount] AS [Expenses], s.[Fte] / m.[AccessionCount] AS [Fte], s.[FteSfn]
        FROM Summary s
        JOIN Projects204 m ON m.[AEProjectNumber] = s.[Project]
        WHERE s.[Source] IN (N'AE', N'UCPath') AND s.[ExpenseSfn] = '204'
    ),
    -- Rule 20x: 201/202/205 expenses follow the employee to their own projects
    -- of the same SFN, divided equally.
    ProjectsBySfn AS
    (
        SELECT e.[UcpEmployeeId], e.[Sfn], e.[AccessionNumber],
               COUNT(*) OVER (PARTITION BY e.[UcpEmployeeId], e.[Sfn]) AS [ProjectCount]
        FROM (SELECT DISTINCT [UcpEmployeeId], [Sfn], [AccessionNumber] FROM Eligible WHERE [Sfn] IN ('201', '202', '205') AND [UcpEmployeeId] IS NOT NULL) e
    ),
    Rule20x AS
    (
        SELECT s.[ExpenseId], CAST(N'20x' AS NVARCHAR(10)) AS [Rule], s.[OrgR], s.[Project] AS [AeProject], m.[AccessionNumber],
               s.[ExpenseSfn], s.[Expenses] / m.[ProjectCount] AS [Expenses], s.[Fte] / m.[ProjectCount] AS [Fte], s.[FteSfn]
        FROM Summary s
        JOIN ProjectsBySfn m ON m.[UcpEmployeeId] = s.[EmployeeId] AND m.[Sfn] = s.[ExpenseSfn]
        WHERE s.[Source] IN (N'AE', N'UCPath') AND s.[ExpenseSfn] IN ('201', '202', '205')
          AND NOT EXISTS (SELECT 1 FROM Rule204 r WHERE r.[ExpenseId] = s.[ExpenseId])
    ),
    -- Rule 220: 13U02 PI expenses (FTE line 241) across all the PI's projects.
    ProjectsAll AS
    (
        SELECT e.[UcpEmployeeId], e.[AccessionNumber],
               COUNT(*) OVER (PARTITION BY e.[UcpEmployeeId]) AS [ProjectCount]
        FROM (SELECT DISTINCT [UcpEmployeeId], [AccessionNumber] FROM Eligible WHERE [UcpEmployeeId] IS NOT NULL) e
    ),
    Rule220 AS
    (
        SELECT s.[ExpenseId], CAST(N'220' AS NVARCHAR(10)) AS [Rule], s.[OrgR], s.[Project] AS [AeProject], m.[AccessionNumber],
               CAST('220' AS NVARCHAR(10)) AS [ExpenseSfn], s.[Expenses] / m.[ProjectCount] AS [Expenses], s.[Fte] / m.[ProjectCount] AS [Fte], s.[FteSfn]
        FROM Summary s
        JOIN ProjectsAll m ON m.[UcpEmployeeId] = s.[EmployeeId]
        WHERE s.[Source] IN (N'AE', N'UCPath') AND s.[Fund] = '13U02' AND s.[FteSfn] = '241'
          AND NOT EXISTS (SELECT 1 FROM Rule204 r WHERE r.[ExpenseId] = s.[ExpenseId])
          AND NOT EXISTS (SELECT 1 FROM Rule20x r WHERE r.[ExpenseId] = s.[ExpenseId])
    ),
    -- Rules FS and CE: the upload rows go whole to their accession.
    RuleUploads AS
    (
        SELECT s.[ExpenseId], CAST(CASE s.[Source] WHEN N'FieldStation' THEN N'FS' ELSE N'CE' END AS NVARCHAR(10)) AS [Rule],
               s.[OrgR], CAST(NULL AS NVARCHAR(50)) AS [AeProject], s.[AccessionNumber],
               s.[ExpenseSfn], s.[Expenses], s.[Fte], s.[FteSfn]
        FROM Summary s
        WHERE s.[Source] IN (N'FieldStation', N'CE')
          AND EXISTS (SELECT 1 FROM Eligible e WHERE e.[AccessionNumber] = s.[AccessionNumber])
    )
    SELECT [ExpenseId], [Rule], [OrgR], [AeProject], [AccessionNumber], [ExpenseSfn],
           CAST([Expenses] AS DECIMAL(19, 4)) AS [Expenses], CAST([Fte] AS DECIMAL(9, 6)) AS [Fte], [FteSfn]
    FROM
    (
        SELECT * FROM Rule204
        UNION ALL SELECT * FROM Rule20x
        UNION ALL SELECT * FROM Rule220
        UNION ALL SELECT * FROM RuleUploads
    ) candidates
);
