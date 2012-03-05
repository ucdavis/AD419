/*
----------------------------------------------------------------------
 PROGRAM: sp_Repopulate_AD419_Reporting_Org
 BY:	Mike Ransom
 USAGE:	EXEC sp_Repopulate_AD419_Reporting_Org

 DESCRIPTION: 
Table AD419_Reporting_Org exists to resolve Org + Chart combos into AD419 reporting org (codes).  Vast majority of codes for AD419 reporting are at level 3 (Organization.Org_3), with the main exception being the CBS departments, which we use the Org_2 value.  I guess I'll hard-code the other exceptions for now: e.g. CABA is a level 5 Org that gets reported separately in AD419.  Ultimately, the right way to do this would be to have a user interface to maintain the list, tho the Org code themselves will be constantly changing, so there's not a whole lot to be gained with a UI.

This sproc is an attempt to move in the right direction--with this, at least it will only have to be done once per reporting season.


 CURRENT STATUS:
10/11/05] Tue Created.  Returns 897 + 55 + 344 rows, respectively. (couple of seconds)
10/12/05] Wed
	Modified to do OrgR re-assignements (e.g. CABA)
	Modified to go against explicit year in FINANCE.ORGANIZATION_HIERARCHY (hard-coded).
		Note: this changed execution time from 2 to 12 seconds.
	Added additional OrgR substitution codes other than CABA. (More still needed)

 NOTES:
	Note, to capture Org structure for particular fiscal year, I've used the specific year rather than the year 9999, which signifies the most recent values.  Since this is hard-coded, it must be modifed and the SProc ALTERed before each year's run.

 MODIFICATIONS: see bottom
 CALLED BY:
 DEPENDENCIES: 
-------------------------------------------------------------------------
*/
CREATE procedure [dbo].[sp_Repopulate_AD419_Reporting_Org]
--PARAMETERS:
	@FiscalYear int = null, -- Fiscal Year to download transactions for.
	@IsDebug bit = 0 -- Set to 1 to print SQL only.
AS
declare @TSQL varchar(max) = '' --Holds T-SQL code to be run with EXEC() function.
-------------------------------------------------------------------------
-- MAIN:
--Drop existing rows:
Select @TSQL = 'DELETE FROM AD419_Reporting_Org'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
--Repopulate:

--CAES and BIOS Level 3, and CAES Level 2 Orgs:
Select @TSQL = 'INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
	SELECT DISTINCT
			Chart Chart,
			Org Org,
			OrgR OrgR,
			NameR OrgR_Name
		FROM 
			FISDataMart.dbo.OrganizationsV Orgs 
		WHERE 
			Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND Period = ''--''
			-- 2017: does not include chart L level 2 orgs without level 3 orgs.
			AND ((Org3 IS NOT NULL) OR (Org3 IS NULL AND Org2 IS NOT NULL AND Chart <> ''L''))
			-- OR
			--AND ((Org1 <> OrgR AND Chart = ''3'') OR (Org2 <> OrgR AND Chart = ''L''))
			
			-- 2023: Includes chart L level 2 orgs without level 3 orgs.
			--AND ((Org3 IS NOT NULL) OR (Org3 IS NULL AND Org2 IS NOT NULL))
			-- OR
			--AND Org1 <> OrgR
			
		ORDER BY Chart, OrgR, Org
		
'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
		
-- All of this was replaced by the above using the OrganizationsV view instead of the Organizations table. 
/*
	--Note: I've done this in 3 sections because of the differences in level where the AD419 reporting Orgs occurs with the CAES, Biosci and Chart L Org structure.  I tried it with DECODE, but that's only good for different controlling values in one field.

--CAES:
Select @TSQL = 'INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
SELECT DISTINCT
			Chart Chart,
			Org Org,
			Org3 OrgR,
			Name3 OrgR_Name
		FROM 
			FISDataMart.dbo.Organizations Orgs 
		WHERE 
			Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND Period = ''--''
			AND Chart1 = ''3'' AND Org1 = ''AAES''
			AND Org3 IS NOT NULL
		ORDER BY Chart, OrgR, Org
		'
		
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
		
--CAES Level 2 Orgs:	(Added [12/5/05], MLR: There are some expenses under the Lev2 org codes)
Select @TSQL = 'INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
SELECT DISTINCT 
			Chart Chart,
			Org Org,
			Org OrgR,
			Name2 OrgR_Name
		FROM 
			FISDataMart.dbo.Organizations Orgs 
		WHERE 
			Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND Period = ''--''
			AND Chart1 = ''3'' AND Org1 = ''AAES''
			AND Org3 IS NULL and Org2 IS NOT NULL
		ORDER BY Chart, OrgR, Org
		'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

--Biosci:
Select @TSQL = 'INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
SELECT DISTINCT 
			Chart Chart,
			Org Org,
			Org2 OrgR,
			Name2 OrgR_Name
		FROM 
			FISDataMart.dbo.Organizations Orgs 
		WHERE 
			Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND Period = ''--''
			AND Chart1 = ''3'' AND Org1 = ''BIOS''
			AND Org2 IS NOT NULL
		ORDER BY Chart, OrgR, Org
		'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

--Cooperative Extension:
Select @TSQL = 'INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
SELECT DISTINCT
			Chart Chart,
			Org Org,
			Org4 OrgR,
			Name4 OrgR_Name
		FROM 
			FISDataMart.dbo.Organizations Orgs 
		WHERE 
			Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND Period = ''--''
			AND Chart1 = ''L'' AND Org2 = ''AAES''
			AND Org4 IS NOT NULL
		ORDER BY Chart, OrgR, Org
		'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
	*/

--Programmatic subsitutions:
--Reviewed [12/20/05] MLR: added additional orgs we missed before, separated into different classes of substitution types

--By Org code:
-- lev 5 org which reports separately
Select @TSQL = 'update AD419_Reporting_Org set OrgR = ''CABA'' where Org=''CABA'';
'	
-- lev 2 Orgs with null org_3
Select @TSQL += 'update AD419_Reporting_Org set OrgR = ''ADNO'' where Org IN (''AADM'',''ACWU'',''AADM'', ''AGAD'',''APRV'');
'
-- lev 2 org, associated with startup of APLS dept. [12/20/05] Tue
Select @TSQL += 'update AD419_Reporting_Org set OrgR = ''APLS'' where Org=''APSC'';
'	
--By OrgR determined above, lev 3 Orgs which are not reported on separately:
--	lev 3 Orgs
Select @TSQL += 'update AD419_Reporting_Org set OrgR = ''ADNO'' where OrgR IN (''AHIS'',''AWRD'',''GRCP'')	;
'
Select @TSQL += 'update AD419_Reporting_Org set OrgR = ''AEDS'' where OrgR=''ALAR'';
'
Select @TSQL += 'update AD419_Reporting_Org set OrgR = ''AHCD'' where OrgR=''AHCH'';
'

	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

/*
original using DECODE: (abandoned because I didn't want nulls in Org3 for AAES level 1, 2 Orgs
INSERT INTO AD419_Reporting_Org
	(Chart, Org, OrgR, OrgR_Name)
SELECT * FROM
	OPENQUERY 
		(FIS_DS_PROD,
		'
		SELECT 
			CHART_NUM Chart,
			ORG_ID Org,
			DECODE (ORG_ID_LEVEL_1, ''AAES'', ORG_ID_LEVEL_3 , ''BIOS'', ORG_ID_LEVEL_2, ''    '') OrgR,
			DECODE (ORG_ID_LEVEL_1, ''AAES'', ORG_NAME_LEVEL_3 , ''BIOS'', ORG_NAME_LEVEL_2, ''    '') OrgR_Name
		FROM 
			FINANCE.ORGANIZATION_HIERARCHY Orgs 
		WHERE 
			FISCAL_YEAR = 9999
			AND 
				(
				(CHART_NUM_LEVEL_1=''3'' AND ORG_ID_LEVEL_1 = ''AAES'')
				OR
				(CHART_NUM_LEVEL_1=''3'' AND ORG_ID_LEVEL_1 = ''BIOS'')
				)
		HAVING OrgR is not null
		ORDER BY Chart, OrgR, Org
		')


*/

-------------------------------------------------------------------------
/*
MODIFICATIONS:
2010-01-12 by Ken Taylor: Revised to use FISDataMart tables vs campus data warehouse.
2010-12-21 by Ken Taylor: Revised to use the FISDataMart OrganizationsV view instead of 
	the Organizations table.

*/
