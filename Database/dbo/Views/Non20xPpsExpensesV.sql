CREATE VIEW dbo.Non20xPpsExpensesV
AS
SELECT        TOP (100) PERCENT NULL AS Accession, t1_1.Exp_SFN, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, 
                         t3.AbbreviatedName AS Title_Code_Name, t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, SUM(t1_1.Expenses) AS Expenses, 0 AS IsAssociated, 
                         1 AS isAssociable, 0 AS IsNonEmpExp, t1_1.Exp_SFN AS Sub_Exp_SFN, SUM(t1_1.FTE) AS FTE, t4.AD419_Line_Num AS FTE_SFN, 
                         t4.Staff_Type_Short_Name AS Staff_Grp_Cd
FROM            (SELECT        LEFT(SFN, 3) AS Exp_SFN, OrgR, Org, EmployeeID AS EID, EmployeeName AS Employee_Name, TitleCd, Chart, Account, SubAccount AS SubAcct, 
                                                    PrincipalInvestigator AS PI_Name, SUM(Amount) AS Expenses, 1 AS IsAssociated, 0 AS isAssociable, 0 AS IsNonEmpExp, LEFT(SFN, 3) 
                                                    AS Sub_Exp_SFN, SUM(FTE) AS FTE
                          FROM            dbo.PPS_ExpensesForNon204Projects AS t1
                          WHERE        (SFN NOT BETWEEN '201' AND '205')
                          GROUP BY Chart, Account, SubAccount, PrincipalInvestigator, OrgR, Org, EmployeeID, EmployeeName, TitleCd, LEFT(SFN, 3)
                          HAVING         (SUM(Amount) <> 0)) AS t1_1 LEFT OUTER JOIN
                         PPSDataMart.dbo.Titles AS t3 ON t1_1.TitleCd = t3.TitleCode LEFT OUTER JOIN
                         dbo.staff_type AS t4 ON t3.StaffType = t4.Staff_Type_Code
GROUP BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, t3.AbbreviatedName, t1_1.Exp_SFN, 
                         t4.AD419_Line_Num, t4.Staff_Type_Short_Name
ORDER BY t1_1.Chart, t1_1.Account, t1_1.SubAcct, t1_1.PI_Name, t1_1.OrgR, t1_1.Org, t1_1.EID, t1_1.Employee_Name, t1_1.TitleCd, Title_Code_Name, t1_1.Exp_SFN, 
                         FTE_SFN, Staff_Grp_Cd