﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: September 16, 2016
-- Description:	Returns a list of any OrgRs that have 
-- non-zero expenses with NULL or non-AD419 departments.
-- Usage:
/*
	SELECT * FROM udf_GetExpensesForNullOrUnknownDepartments()
*/
-- Modifications:
--	20170106 by kjt: Added Org and additional joins to ExpenseOrgR_X_AD419OrgR table.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetExpensesForNullOrUnknownDepartments] 
(
)
RETURNS 
@UnknownOrgR_Expenses TABLE 
(
	Chart varchar(2), OrgR varchar(4), Org varchar(4), Account varchar(7), Expenses money
)
AS
BEGIN

	INSERT INTO @UnknownOrgR_Expenses
	SELECT Chart, OrgR, Org, Account, SUM([Expenses]) Expenses
	FROM [dbo].[UFY_FFY_FIS_Expenses]
	WHERE OrgR IS NULL OR OrgR NOT IN (
		SELECT OrgR 
		FROM [dbo].[ReportingOrg] where isActive = 1 
  )
  AND OrgR NOT IN (
	SELECT ExpenseOrgR
	FROM ExpenseOrgR_X_AD419OrgR
	WHERE ExpenseOrg IS NULL
  )
  AND Org NOT IN (
	SELECT ExpenseOrg
	FROM ExpenseOrgR_X_AD419OrgR
	WHERE ExpenseOrg IS NOT NULL
  )
  GROUP BY Chart, OrgR, Org, Account HAVING SUM(Expenses) <> 0 
	
	RETURN 
END