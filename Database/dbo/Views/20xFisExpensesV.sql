CREATE VIEW dbo.[20xFisExpensesV]
AS
SELECT        TOP (100) PERCENT Project, Accession, Exp_SFN, OrgR, Org, Chart, Account, SubAcct, PI_Name, SUM(Expenses) AS Expenses, IsExpired, 1 AS IsAssociated, 
                         0 AS isAssociable, 1 AS IsNonEmpExp, Exp_SFN AS Sub_Exp_SFN
FROM            (SELECT        t2.ProjectNumber AS Project, t2.AccessionNumber AS Accession, t1.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, 
                                                    t1.PrincipalInvestigator AS PI_Name, SUM(t1.Expenses) AS Expenses, t2.IsExpired
                          FROM            dbo.FIS_ExpensesForNon204Projects AS t1 LEFT OUTER JOIN
                                                    dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
                          WHERE        (t1.SFN IN ('201', '202', '203', '205')) AND (t2.AccessionNumber IS NOT NULL) AND (t2.IsExpired = 0)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.SFN, t2.AccessionNumber, t2.ProjectNumber, t2.IsExpired
                          HAVING         (SUM(t1.Expenses) <> 0)
                          UNION
                          SELECT        t4.ProjectNumber AS Project, t3.ToAccession AS Accession, t1.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, 
                                                   t1.PrincipalInvestigator AS PI_Name, SUM(t1.Expenses) AS Expenses, t2.IsExpired
                          FROM            dbo.FIS_ExpensesForNon204Projects AS t1 LEFT OUTER JOIN
                                                   dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account LEFT OUTER JOIN
                                                   dbo.ExpiredProjectCrossReference AS t3 ON t2.AccessionNumber = t3.FromAccession LEFT OUTER JOIN
                                                   dbo.AllProjectsNew AS t4 ON t3.ToAccession = t4.AccessionNumber AND t4.IsUCD = 1
                          WHERE        (t1.SFN IN ('201', '202', '203', '205')) AND (t2.IsExpired = 1)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.SFN, t2.IsExpired, t3.ToAccession, t2.AccessionNumber, 
                                                   t4.ProjectNumber
                          HAVING        (SUM(t1.Expenses) > 0)) AS t1_1
GROUP BY Chart, Account, SubAcct, PI_Name, OrgR, Org, Exp_SFN, Accession, Project, IsExpired