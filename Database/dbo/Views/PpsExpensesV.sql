CREATE VIEW dbo.PpsExpensesV
AS
SELECT        [Project], [Accession], [Exp_SFN], [OrgR], [Org], [EID], [Employee_Name], [TitleCd], [Title_Code_Name], [Chart], [Account], [SubAcct], [PI_Name], [Expenses], 
                         [IsExpired], [IsAssociated], [isAssociable], [IsNonEmpExp], [Sub_Exp_SFN], [FTE], [FTE_SFN], [Staff_Grp_Cd]
FROM            [AD419].[dbo].[204PpsExpensesV]
UNION
SELECT        [Project], [Accession], [Exp_SFN], [OrgR], [Org], [EID], [Employee_Name], [TitleCd], [Title_Code_Name], [Chart], [Account], [SubAcct], [PI_Name], [Expenses], 
                         [IsExpired], [IsAssociated], [isAssociable], [IsNonEmpExp], [Sub_Exp_SFN], [FTE], [FTE_SFN], [Staff_Grp_Cd]
FROM            [AD419].[dbo].[20xPpsExpensesV]
UNION
SELECT        NULL [Project], [Accession], [Exp_SFN], [OrgR], [Org], [EID], [Employee_Name], [TitleCd], [Title_Code_Name], [Chart], [Account], [SubAcct], [PI_Name], [Expenses], 
                         0 AS [IsExpired], [IsAssociated], [isAssociable], [IsNonEmpExp], [Sub_Exp_SFN], [FTE], [FTE_SFN], [Staff_Grp_Cd]
FROM            [AD419].[dbo].[Non20xPpsExpensesV]