CREATE VIEW [data].[v_TransactionOrgR]
AS
-- OrgR assignment per imported transaction. This is the single place the
-- assignment rules live; the expense summary and CAES-DONBOT write-back read
-- from here. Inclusion is not applied; consumers filter included rows.
--
-- UCPath: title code (JobCode) 1010 is Associate Deans and is always ADNO so
-- it feeds the admin proration at final report time. Everything else uses the
-- financial department mapping. AE has no title code and uses the mapping
-- only. Unmapped departments yield NULL.
SELECT
    'UCPath' AS [Source],
    u.[LaborTransactionId] AS [TransactionId],
    u.[FinancialDepartment],
    u.[JobCode],
    CASE WHEN u.[JobCode] = '1010' THEN 'ADNO' ELSE f.[OrgR] END AS [OrgR]
FROM [data].[UcPathTransactions] u
LEFT JOIN [data].[OrgRFinancialDepartments] f
    ON f.[FinancialDepartment] = u.[FinancialDepartment]

UNION ALL

SELECT
    'AE' AS [Source],
    a.[Id] AS [TransactionId],
    a.[FinancialDepartment],
    CAST(NULL AS NVARCHAR(4)) AS [JobCode],
    f.[OrgR]
FROM [data].[AETransactions] a
LEFT JOIN [data].[OrgRFinancialDepartments] f
    ON f.[FinancialDepartment] = a.[FinancialDepartment];
