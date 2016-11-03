CREATE VIEW dbo.Non20xFisExpensesV
AS
SELECT        TOP (100) PERCENT NULL AS Accession, Exp_SFN, OrgR, Org, Chart, Account, SubAcct, PI_Name, SUM(Expenses) AS Expenses, 0 AS IsAssociated, 
                         1 AS isAssociable, 1 AS IsNonEmpExp, Exp_SFN AS Sub_Exp_SFN
FROM            (SELECT        LEFT(SFN, 3) AS Exp_SFN, OrgR, Org, Chart, Account, SubAccount AS SubAcct, PrincipalInvestigator AS PI_Name, SUM(Expenses) AS Expenses
                          FROM            dbo.FIS_ExpensesForNon204Projects AS t1
                          WHERE        (LEFT(SFN, 3) NOT BETWEEN '201' AND '205')
                          GROUP BY Chart, Account, SubAccount, PrincipalInvestigator, OrgR, Org, LEFT(SFN, 3)
                          HAVING         (SUM(Expenses) <> 0)) AS t1_1
GROUP BY Chart, Account, SubAcct, PI_Name, OrgR, Org, Exp_SFN