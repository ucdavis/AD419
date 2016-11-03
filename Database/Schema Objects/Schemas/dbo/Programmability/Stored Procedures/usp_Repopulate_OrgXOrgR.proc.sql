/****** Object:  StoredProcedure [dbo].[usp_Repopulate_OrgXOrgR]    Script Date: 3/30/2016 10:00:15 AM ******/
/*
----------------------------------------------------------------------
 PROGRAM: usp_Repopulate_OrgXOrgR
 BY:	Ken Taylor
 Create date: 11/16/06

 USAGE:
	EXEC usp_Repopulate_OrgXOrgR @FiscalYear = 2015, @IsDebug = 1

DESCRIPTION: 
Table OrgXOrgR exists to resolve Org + Chart combos into AD419 reporting org (OrgR) codes.
  The vast majority of codes for AD419 reporting are at level 3 (Organization.Org_3),
   with the main exception being the CBS departments, which we use the Org_2 value.
     There are other AD419 reporting orgs that are "non standard", i.e. not at the normal levels for their source.
       Resolving their OrgR requires hard-coding. e.g. CABA, which is a level 5 Org.
         Ultimately, the right way to do this might be to have a user interface to maintain the list,
          tho the Orgs code themselves will be constantly changing, so there's not a whole lot to be gained with a UI.

This sproc is an attempt to move in the right direction--with this, at least it will only have to
 be done once per reporting season.

 NOTES:
	Note, to capture Org structure for particular fiscal year, I've used the specific year rather than the year 9999, which signifies the most recent values.  Since this is hard-coded, it must be modifed and the SProc ALTERed before each year's run.

 MODIFICATIONS: 
	2016-04-21 by kjt: Revised to use the 9999 fiscal year and the "--" fiscal period in order to avoid multiple
		OrgRs for the same Org.  Having multiple OrgRs for the same Org would cause duplicate records when using the
		table for joins with expenses.
	2016-08-08 by kjt: Reworked to use the new [dbo].[UFYOrganizationsOrgR_v] view, plus only get orgs that were active during the appropriate report period.
	2016-09-29 by kjt: Removed date filter as these Orgs all are for year 9999.
 CALLED BY:
 DEPENDENCIES: 
-------------------------------------------------------------------------
*/
CREATE procedure [dbo].[usp_Repopulate_OrgXOrgR]
--PARAMETERS:
	@FiscalYear int = 2015, -- Fiscal Year.
	@IsDebug bit = 0 -- set to 1 to print SQL.
AS
declare @TSQL varchar(5000)	--Holds T-SQL code to be run with EXEC() function.
-------------------------------------------------------------------------
-- MAIN:
--Drop existing rows:
Select @TSQL = 'TRUNCATE TABLE AllOrgXOrgR'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
--Repopulate:

Select @TSQL = '
INSERT INTO AllOrgXOrgR
	(Chart, Org, OrgR)
SELECT DISTINCT 
	Chart, Org, OrgR
FROM 
	[dbo].[UFYOrganizationsOrgR_v]
ORDER BY 
	Chart, OrgR, Org
'
	
IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
