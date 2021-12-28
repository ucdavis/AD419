

-- =============================================
-- Author:		Ken Taylor
-- Create date: January 6th, 2017
-- Description:	Returns a list of Account Details for any OrgRs (and Orgs) that have 
-- non-zero expenses with NULL or non-AD419 departments.
-- Usage:
/*

	SELECT * FROM udf_GetAccountDetailsForNullOrUnknownDepartments()

*/
-- Modifications:
--	2018-12-05 by kjt: Expanded where clause to filter out accounts present in
--		ArcCodeAccountExclusions table.
--	2018-12-07 by kjt: Revised where clause to work as desired.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAccountDetailsForNullOrUnknownDepartments] 
(
)
RETURNS 
@UnknownOrgR_Expenses TABLE 
(
	Chart varchar(2), 
	OrgR varchar(4), 
	SuggestedOrgR varchar(4),
	Org varchar(4), 
	Account varchar(7), 
	AccountName varchar(40),
	ARCName varchar(40),
	School varchar(12),
	Department varchar(50),
	MgrName varchar(30),
	PrincipalInvestigatorName varchar(30),
	EmployeeId varchar(9),
	Purpose varchar(400)
)
AS
BEGIN

	INSERT INTO @UnknownOrgR_Expenses
	SELECT 
		Accounts.Chart, 
		OrgR,
	CASE WHEN OrgR = 'BGEN' THEN
	CASE
	WHEN (t2.Abbreviation = 'BIO SCI' AND t3.Abbreviation = 'PLANT BIOLOGY') OR ARCName = 'Plant biology' THEN 'BPLB'
	WHEN t2.Abbreviation = 'AG' AND t3.Abbreviation = 'NUTR' THEN 'ANUT'
	WHEN Accounts.ORG = 'MICH' THEN 'BMCB'
	ELSE 'ADNO' END
END AS SuggestedOrgR, 
		Accounts.Org, 
		Account, 
		AccountName, 
		ARCName, t2.Abbreviation School, 
		t3.Abbreviation Department, 
		MgrName, 
		PrincipalInvestigatorName, 
		EmployeeId, 
		Purpose 
	FROM FisDataMart.dbo.Accounts
	LEFT OUTER JOIN FisDataMart.dbo.ARCCodes On Accounts.AnnualReportCode = ARCCode
	LEFT OUTER JOIN PPSDataMart.dbo.Persons t1 ON PrincipalInvestigatorName LIKE FullName
	LEFT OUTER JOIN PPSDataMart.dbo.Schools t2 ON t1.SchoolDivision = t2.SchoolCode
	LEFT OUTER JOIN PPSDataMart.dbo.Departments t3 ON t1.HomeDepartment = t3.HomeDeptNo
	LEFT OUTER JOIN AD419.dbo.UFYOrganizationsOrgR_v t4 ON Accounts.Org = t4.Org AND Accounts.Chart = t4.Chart
	WHERE 
		Year = 9999 AND 
		Period = '--' AND 
		Accounts.Chart+Accounts.Account IN (
			SELECT Chart+Account
			FROM [dbo].[UFY_FFY_FIS_Expenses] t1
			WHERE 
				(OrgR IS NULL OR -- Blank OrgRs OR
				 OrgR NOT IN (   -- Inactive or invalid OrgRs.
						SELECT OrgR 
						FROM [dbo].[ReportingOrg] where isActive = 1
					) 
				)
				AND  -- OrgRs are not already present in Remap table table that apply to all child Orgs: 
						OrgR NOT IN (
							SELECT ExpenseOrgR 
							FROM AD419.dbo.ExpenseOrgR_X_AD419OrgR
							WHERE ExpenseOrg IS NULL
						)
				AND -- Orgs are not already present in Remap table that apply to a specific parent org:
						Org NOT IN (
							SELECT ExpenseOrg
							FROM AD419.dbo.ExpenseOrgR_X_AD419OrgR
							WHERE ExpenseOrg IS NOT NULL
						) 
			GROUP BY t1.Chart, Account HAVING SUM(Expenses) <> 0 
		) 
		AND -- Having accounts not already present in the ARC/Account exclusions table:
		Accounts.Chart + Accounts.Account NOT IN
		(
			SELECT Accounts.Chart + Account
			FROM [dbo].[ArcCodeAccountExclusions] E
			INNER JOIN [dbo].[CurrentFiscalYear] ON Year = FiscalYear  
		)
	ORDER BY Accounts.Chart, Account
	
	RETURN 
END
GO


