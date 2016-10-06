CREATE VIEW dbo.[204AcctXProjV]
AS
SELECT        t1.Account AS AccountID, SUM(t1.Expenses) AS Expenses, SUM(t1.Expenses) AS DividedAmount, SUM(t1.FTE) AS FTE, t1.AccessionNumber AS Accession, 
                         t1.ProjectNumber, t1.Chart, NULL AS Is219, t1.AwardNumber AS CSREES_ContractNo, COALESCE (t2.OpFund_AwardNum, t2.Accounts_AwardNum) AS AwardNum, 
                         t1.ProjectEndDate, 1 ^ t1.IsExpired AS IsCurrentProject, t1.Org, t1.OrgR, CASE WHEN ExcludedByAccount = 1 OR
                         IsUCD = 0 THEN 1 ELSE 0 END AS IsExcludedExpense, t1.OpFundNum
FROM            dbo.AllAccountsFor204Projects AS t1 INNER JOIN
                         dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.SFN = '204'
GROUP BY t1.Chart, t1.Account, t1.AccessionNumber, t1.ProjectNumber, t1.AwardNumber, COALESCE (t2.OpFund_AwardNum, t2.Accounts_AwardNum), t1.OrgR, t1.Org, 
                         t1.ProjectEndDate, t1.IsExpired, CASE WHEN ExcludedByAccount = 1 OR
                         IsUCD = 0 THEN 1 ELSE 0 END, t1.OpFundNum
HAVING        (SUM(t1.Expenses) <> 0) AND (SUM(t1.Expenses) IS NOT NULL)