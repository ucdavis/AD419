/****** Object:  StoredProcedure [dbo].[usp_Repopulate_OrgXOrgR]    Script Date: 3/30/2016 10:00:15 AM ******/
/*
----------------------------------------------------------------------
 PROGRAM: usp_Repopulate_OrgXOrgR
 BY:	Ken Taylor
 Create date: 11/16/06

 USAGE:


	EXEC usp_Repopulate_OrgXOrgR @FiscalYear = 2016, @IsDebug = 1


	-- *Note that the @FiscalYear parameter is now just a place holder so that it matches the same signature as the
	--	  other stored procedures used by the AD-419 DataHelper application.

DESCRIPTION: 
Table OrgXOrgR exists to resolve Org + Chart combos into AD419 reporting org (OrgR) codes.
  The vast majority of codes for AD419 reporting are at level 3 (Organization.Org_3), except perhaps for CBS.
     However, there are other AD419 reporting organizations that are non-standard, i.e. CABA, which cannot be
		mapped automatically without the use of the new Expense department to AD-419 OrgR remap table: 
			ExpenseOrgR_X_AD419OrgR.  This table is now included as a join.
 NOTES: Now that we are reporting using the Federal Fiscal Year (FFY) Vs. the State Fiscal Year (SFY), we are using 
		  the Universal Fiscal Year (UFY), i.e., 9999 fiscal year and "--" period.  The UFY has been vetted to provide
		    the most accurate results when it comes to matching accounts to their corresponding Departments.
	
 MODIFICATIONS: 
	2016-04-21 by kjt: Revised to use the 9999 fiscal year and the "--" fiscal period in order to avoid multiple
		OrgRs for the same Org.  Having multiple OrgRs for the same Org would cause duplicate records when using the
		table for joins with expenses.
	2016-08-08 by kjt: Reworked to use the new [dbo].[UFYOrganizationsOrgR_v] view, plus only get orgs that were active during the appropriate report period.
	2016-09-29 by kjt: Removed date filter as these Orgs all are for year 9999.
 CALLED BY:
 CALLED BY:
 DEPENDENCIES: 
-------------------------------------------------------------------------
*/
CREATE PROCEDURE [dbo].[usp_Repopulate_OrgXOrgR]
--PARAMETERS:
	@FiscalYear int = 2016, -- Fiscal Year: No longer used, but kept for method signature standardization.
	@IsDebug bit = 0		-- set to 1 to print SQL.
AS
	DECLARE @TSQL varchar(5000)	--Holds T-SQL code to be run with EXEC() function.
-------------------------------------------------------------------------
-- MAIN:
--Drop existing rows:
	SELECT @TSQL = '
	TRUNCATE TABLE AllOrgXOrgR
'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

--Repopulate:

	SELECT @TSQL = '
	INSERT INTO AllOrgXOrgR
		(Chart, Org, OrgR)
	SELECT DISTINCT 
		t1.Chart, t1.Org, OrgR
	FROM 
		[dbo].[UFYOrganizationsOrgR_v]  AS t1
	ORDER BY 
		t1.Chart, OrgR, t1.Org
'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
