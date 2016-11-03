CREATE VIEW dbo.[20xPpsExpensesV]
AS
SELECT        TOP (100) PERCENT t1_1.Project, t1_1.Accession, t1_1.Exp_SFN, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, 
                         t3.AbbreviatedName AS Title_Code_Name, t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, SUM(t1_1.Expenses) AS Expenses, t1_1.IsExpired, 
                         1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t1_1.Exp_SFN AS Sub_Exp_SFN, SUM(t1_1.FTE) AS FTE, t4.AD419_Line_Num AS FTE_SFN, 
                         t4.Staff_Type_Short_Name AS Staff_Grp_Cd
FROM            (SELECT        t2.ProjectNumber AS Project, t2.AccessionNumber AS Accession, t1.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.EmployeeID AS EID, 
                                                    t1.EmployeeName AS Employee_Name, t1.TitleCd, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, t1.PrincipalInvestigator AS PI_Name, SUM(t1.Amount) 
                                                    AS Expenses, t2.IsExpired, 1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t1.SFN + 's' AS Sub_Exp_SFN, SUM(t1.FTE) AS FTE
                          FROM            dbo.PPS_ExpensesForNon204Projects AS t1 LEFT OUTER JOIN
                                                    dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
                          WHERE        (t1.SFN IN ('201', '202', '203', '205')) AND (t2.AccessionNumber IS NOT NULL) AND (t2.IsExpired = 0)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.EmployeeID, t1.EmployeeName, t1.TitleCd, t1.SFN, t2.AccessionNumber, 
                                                    t2.ProjectNumber, t2.IsExpired
                          HAVING         (SUM(t1.Amount) <> 0)
                          UNION
                          SELECT        t4.ProjectNumber AS Project, t3.ToAccession AS Accession, t1.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.EmployeeID AS EID, 
                                                   t1.EmployeeName AS Employee_Name, t1.TitleCd, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, t1.PrincipalInvestigator AS PI_Name, SUM(t1.Amount) 
                                                   AS Expenses, t2.IsExpired, 1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t1.SFN AS Sub_Exp_SFN, SUM(t1.FTE) AS FTE
                          FROM            dbo.PPS_ExpensesForNon204Projects AS t1 LEFT OUTER JOIN
                                                   dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account LEFT OUTER JOIN
                                                   dbo.ExpiredProjectCrossReference AS t3 ON t2.AccessionNumber = t3.FromAccession LEFT OUTER JOIN
                                                   dbo.AllProjectsNew AS t4 ON t3.ToAccession = t4.AccessionNumber AND t4.IsUCD = 1
                          WHERE        (t1.SFN IN ('201', '202', '203', '205')) AND (t2.IsExpired = 1)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.EmployeeID, t1.EmployeeName, t1.TitleCd, t1.SFN, t2.IsExpired, 
                                                   t3.ToAccession, t2.AccessionNumber, t4.ProjectNumber
                          HAVING        (SUM(t1.Amount) > 0)) AS t1_1 LEFT OUTER JOIN
                         PPSDataMart.dbo.Titles AS t3 ON t1_1.TitleCd = t3.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS t4 ON t3.StaffType = t4.Staff_Type_Code
GROUP BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, t3.AbbreviatedName, t1_1.Exp_SFN, 
                         t1_1.Accession, t1_1.Project, t1_1.IsExpired, t4.AD419_Line_Num, t4.Staff_Type_Short_Name