-- =============================================
-- Author:		Ken Taylor
-- Create date: 2009-10-21
-- Description:	This is a modification of the Expenses_FIS_JV view that allows passing the Fiscal Year param.
-- Modifications: 2010-03-12 by Ken Taylor: Changed AD419_Reporting_Org join to use OrgXOrgR table 
-- instead since AD419_Reporting_Org table has been dropped and replaced by the normallized
-- ReportingOrg and OrgXOrgR tables.
-- =============================================
CREATE FUNCTION [dbo].[Expenses_FIS_JV]
(	
	-- Add the parameters for the function here
	@FiscalYear int 
)
RETURNS @Expenses_FIS_JV TABLE (
	Org_R char(4),
	Account varchar(7),
	SubAccount varchar(5),
	ObjConsol varchar(4),
	Expenses float
)
AS
BEGIN
	INSERT INTO @Expenses_FIS_JV
	(
		Org_R,
		Account,
		SubAccount,
		ObjConsol,
		Expenses
	)
SELECT DISTINCT 
                      dbo.OrgXOrgR.OrgR AS Org_R,
                      Raw_FIS_JV_Expenses.Account,
                      Raw_FIS_JV_Expenses.SubAccount, 
                      Raw_FIS_JV_Expenses.ObjConsol,
                      SUM(CONVERT(decimal(12, 2), Raw_FIS_JV_Expenses.EXPENSES)) AS Expenses
FROM
         FISDataMart.dbo.Accounts LEFT OUTER JOIN

         dbo.OrgXOrgR ON FISDataMart.dbo.Accounts.Chart = dbo.OrgXOrgR.Chart
         AND 
         FISDataMart.dbo.Accounts.Org = dbo.OrgXOrgR.Org RIGHT OUTER JOIN
         dbo.Raw_FIS_JV_Expenses AS Raw_FIS_JV_Expenses INNER JOIN
         dbo.Expenses_PPS ON Raw_FIS_JV_Expenses.Account = dbo.Expenses_PPS.Account 
         AND 
         Raw_FIS_JV_Expenses.ObjConsol = dbo.Expenses_PPS.ObjConsol
         AND 
         Raw_FIS_JV_Expenses.SubAccount = dbo.Expenses_PPS.SubAcct ON 
         FISDataMart.dbo.Accounts.Account = Raw_FIS_JV_Expenses.Account
WHERE     (FISDataMart.dbo.Accounts.Chart = '3')
		 AND (FISDataMart.dbo.Accounts.Year = @FiscalYear) 
		 AND (FISDataMart.dbo.Accounts.Period = '--')
GROUP BY dbo.OrgXOrgR.OrgR,
		 Raw_FIS_JV_Expenses.Account,
		 Raw_FIS_JV_Expenses.ObjConsol, 
         Raw_FIS_JV_Expenses.SubAccount
RETURN
END
