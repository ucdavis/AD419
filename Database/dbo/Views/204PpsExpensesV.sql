CREATE VIEW dbo.[204PpsExpensesV]
AS
SELECT        TOP (100) PERCENT t1_1.Project, t1_1.Accession, t1_1.Exp_SFN, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, 
                         t3.AbbreviatedName AS Title_Code_Name, t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, SUM(t1_1.Expenses) AS Expenses, t1_1.IsExpired, 
                         1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t1_1.Exp_SFN AS Sub_Exp_SFN, SUM(t1_1.FTE) AS FTE, t4.AD419_Line_Num AS FTE_SFN, 
                         t4.Staff_Type_Short_Name AS Staff_Grp_Cd
FROM            (SELECT        t2.ProjectNumber AS Project, t2.AccessionNumber AS Accession, t2.SFN AS Exp_SFN, t1.OrgR, t1.Org, t1.EmployeeID AS EID, 
                                                    t1.EmployeeName AS Employee_Name, t1.TitleCd, t1.Chart, t1.Account, t1.SubAccount AS SubAcct, t1.PrincipalInvestigator AS PI_Name, SUM(t1.Amount) 
                                                    AS Expenses, t2.IsExpired, 1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, t2.SFN AS Sub_Exp_SFN, SUM(t1.FTE) AS FTE
                          FROM            dbo.PPS_ExpensesFor204Projects AS t1 INNER JOIN
                                                    dbo.FFY_SFN_Entries AS t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account INNER JOIN
                                                        (SELECT        AccessionNumber
                                                          FROM            dbo.FFY_SFN_Entries
                                                          WHERE        (IsExpired = 0) AND (SFN = '204')
                                                          GROUP BY AccessionNumber
                                                          HAVING         (SUM(Expenses) > 0)) AS t3_1 ON t2.AccessionNumber = t3_1.AccessionNumber
                          WHERE        (t2.SFN IN ('204')) AND (t2.AccessionNumber IS NOT NULL) AND (t2.IsExpired = 0)
                          GROUP BY t1.Chart, t1.Account, t1.SubAccount, t1.PrincipalInvestigator, t1.OrgR, t1.Org, t1.EmployeeID, t1.EmployeeName, t1.TitleCd, t2.SFN, t2.AccessionNumber, 
                                                    t2.ProjectNumber, t2.IsExpired
                          HAVING         (SUM(t1.Amount) <> 0)) AS t1_1 LEFT OUTER JOIN
                         PPSDataMart.dbo.Titles AS t3 ON t1_1.TitleCd = t3.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS t4 ON t3.StaffType = t4.Staff_Type_Code
GROUP BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, t3.AbbreviatedName, t1_1.Exp_SFN, 
                         t1_1.Accession, t1_1.Project, t1_1.IsExpired, t4.AD419_Line_Num, t4.Staff_Type_Short_Name
ORDER BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, Title_Code_Name, t1_1.Exp_SFN, 
                         t1_1.Accession, t1_1.Project, t1_1.IsExpired, FTE_SFN, Staff_Grp_Cd