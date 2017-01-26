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
--
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
	Select 
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
	from FisDataMart.dbo.Accounts 
	left outer join FisDataMart.dbo.ARCCodes On Accounts.AnnualReportCode = ARCCode
	left outer join PPSDataMart.dbo.Persons t1 ON PrincipalInvestigatorName LIKE FullName
	LEFT OUTER JOIN PPSDataMart.dbo.Schools t2 ON t1.SchoolDivision = t2.SchoolCode
	LEFT OUTER JOIN PPSDataMart.dbo.Departments t3 ON t1.HomeDepartment = t3.HomeDeptNo
	LEFT OUTER JOIN AD419.dbo.UFYOrganizationsOrgR_v t4 ON Accounts.Org = t4.Org AND Accounts.Chart = t4.Chart
	where 
		year = 9999 and 
		period = '--' and 
		Accounts.chart+account in (
			SELECT Chart+Account
			FROM [dbo].[UFY_FFY_FIS_Expenses] t1
			WHERE 
				OrgR IS NULL OR OrgR NOT IN (
					SELECT OrgR 
					FROM [dbo].[ReportingOrg] where isActive = 1
				) AND
				OrgR NOT IN (
					SELECT ExpenseOrgR 
					FROM AD419.dbo.ExpenseOrgR_X_AD419OrgR
					WHERE ExpenseOrg IS NULL
				)
				AND
				Org NOT IN (
					SELECT ExpenseOrg
					FROM AD419.dbo.ExpenseOrgR_X_AD419OrgR
					WHERE ExpenseOrg IS NOT NULL
  )

			GROUP BY t1.Chart, Account HAVING SUM(Expenses) <> 0 
		)
	Order by Accounts.Chart, Account
	
	RETURN 
END
GO


