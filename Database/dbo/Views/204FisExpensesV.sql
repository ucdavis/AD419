CREATE VIEW dbo.[204FisExpensesV]
AS
SELECT        TOP (100) PERCENT t2.ProjectNumber AS Project, t2.AccessionNumber AS Accession, t2.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.Chart, t1.Account, 
                         t1.SubAccount AS SubAcct, t1.PrincipalInvestigator AS PI_Name, SUM(t1.Expenses) AS Expenses, t2.IsExpired, 1 AS IsAssociated, 0 AS isAssociable, 
                         1 AS IsNonEmpExp, t2.SFN AS Sub_Exp_SFN
FROM            dbo.FIS_ExpensesFor204Projects AS t1 INNER JOIN
                         dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.SFN = '204' INNER JOIN
                             (SELECT        AccessionNumber
                               FROM            dbo.FFY_SFN_Entries
                               WHERE        (IsExpired = 0) AND (SFN = '204')
                               GROUP BY AccessionNumber
                               HAVING         (SUM(Expenses) > 0)) AS t3 ON t2.AccessionNumber = t3.AccessionNumber
WHERE        (t2.AccessionNumber IS NOT NULL) AND (t2.IsExpired = 0)
GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t2.SFN, t2.AccessionNumber, t2.ProjectNumber, t2.IsExpired
HAVING        (SUM(t1.Expenses) <> 0)
ORDER BY t1.Chart, t1.Account, SubAcct, PI_Name, t1.OrgR, t1.Org, Exp_SFN, Accession, Project, t2.IsExpired