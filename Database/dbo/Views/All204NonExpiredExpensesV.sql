CREATE VIEW dbo.All204NonExpiredExpensesV
AS
SELECT DISTINCT t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t2.[OrgR], t1.[Org], t1.[Expenses]
FROM            UFY_FFY_FIS_Expenses t1 INNER JOIN
                         AllAccountsFor204Projects t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
WHERE        IsExpired = 0 AND IsUCD = 1
GROUP BY t1.Chart, t1.Account, t1.subAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t2.[OrgR], t1.[Org], t1.[Expenses]
UNION
SELECT        t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t1.[OrgR] OrgR, t1.[Org], t1.Expenses
FROM            [AD419].[dbo].[Missing204AccountExpenses] t1
WHERE        IsExpired = 0 AND IsUCD = 1
GROUP BY t1.[Chart], t1.[Account], t1.SubAccount, t1.PrincipalInvestigator, t1.[AnnualReportCode], t1.[OpFundNum], t1.[ConsolidationCode], t1.[TransDocType], t1.[OrgR], t1.[Org], t1.Expenses