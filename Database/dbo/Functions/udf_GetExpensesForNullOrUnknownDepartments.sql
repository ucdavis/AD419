-- =============================================
-- Author:		Ken Taylor
-- Create date: September 16, 2016
-- Description:	Returns a list of any OrgRs that have 
-- non-zero expenses with NULL or non-AD419 departments.
-- Usage:
/*
	SELECT * FROM udf_GetExpensesForNullOrUnknownDepartments()
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_GetExpensesForNullOrUnknownDepartments 
(
)
RETURNS 
@UnknownOrgR_Expenses TABLE 
(
	Chart varchar(2), OrgR varchar(4), Account varchar(7), Expenses money
)
AS
BEGIN

	INSERT INTO @UnknownOrgR_Expenses
	SELECT Chart, OrgR, Account, SUM([Expenses]) Expenses
	FROM [dbo].[UFY_FFY_FIS_Expenses]
	WHERE OrgR IS NULL OR OrgR NOT IN (
		SELECT OrgR 
		FROM [dbo].[ReportingOrg] where isActive = 1 
  )
  GROUP BY Chart, OrgR, Account HAVING SUM(Expenses) <> 0 
	
	RETURN 
END