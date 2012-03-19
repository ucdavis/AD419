/*
----------------------------------------------------------------------
 PROGRAM: usp_Repopulate_OrgXOrgR
 BY:	Mike Ransom
 USAGE:
	EXEC usp_Repopulate_OrgXOrgR

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

CURRENT STATUS:
[12/29/2010] Wed by kjt:
	Re-coding to work with using the AllOrgXOrgR table, and not remap any of the orgRs
        as it had done previously.

 NOTES:
	Note, to capture Org structure for particular fiscal year, I've used the specific year rather than the year 9999, which signifies the most recent values.  Since this is hard-coded, it must be modifed and the SProc ALTERed before each year's run.

 MODIFICATIONS: see bottom
 CALLED BY:
 DEPENDENCIES: 
-------------------------------------------------------------------------
*/
CREATE procedure [dbo].[usp_Repopulate_OrgXOrgR]
--PARAMETERS:
	@FiscalYear int = 2009, -- Fiscal Year.
	@IsDebug bit = 0 -- set to 1 to print SQL.
AS
declare @TSQL varchar(5000)	--Holds T-SQL code to be run with EXEC() function.
-------------------------------------------------------------------------
-- MAIN:
--Drop existing rows:
Select @TSQL = 'DELETE FROM AllOrgXOrgR'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
--Repopulate:

	--Note: This needs to be done with 4 queries plus an org-by-org section because
	-- of the differences in level where the AD419 reporting Orgs occurs with the CAES,
	-- Biosci and Chart L Org structure.

Select @TSQL = 'INSERT INTO AllOrgXOrgR
	(Chart, Org, OrgR/*, OrgR_Name*/
	)
	SELECT DISTINCT 
	Chart, Org, OrgR
FROM 
	FISDataMart.dbo.OrganizationsV Orgs 
WHERE 
	Year = ' + Convert(varchar(4), @FiscalYear) + '  AND Period = ''--''
	AND Org1 IN (''AAES'', ''BIOS'')
	-- 2017: does not include chart L level 2 orgs without level 3 orgs, as did the old code.
	AND ((Org3 IS NOT NULL) OR (Org3 IS NULL AND Org2 IS NOT NULL AND Chart <> ''L''))
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

-- [12/20/2010] by kjt: Commented this out because this functionality can now be done with a single select 
-- statement using the new OrganizationsV view.	 (See above)	
/*

--CAES:
Select @TSQL = 'INSERT INTO OrgXOrgR
	(Chart, Org, OrgR/*, OrgR_Name*/
	)
SELECT DISTINCT 
			Chart Chart,
			Org Org,
			Org3 OrgR
			--,Name3 OrgR_Name
		FROM 
			FISDataMart.dbo.OrganizationsV Orgs 
		WHERE 
			Year = ' + Convert(varchar(4), @FiscalYear) + ' AND Period = ''--''
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
Select @TSQL = 'INSERT INTO OrgXOrgR
	(Chart, Org, OrgR/*, OrgR_Name*/
	)
SELECT DISTINCT
			Chart Chart,
			Org Org,
			Org2 OrgR
			--,Name2 OrgR_Name
		FROM 
			FISDataMart.dbo.OrganizationsV Orgs 
		WHERE 
			Year = ' + Convert(varchar(4), @FiscalYear) + ' AND Period = ''--''
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
Select @TSQL = 'INSERT INTO OrgXOrgR
	(Chart, Org, OrgR/*, OrgR_Name*/
	)
SELECT DISTINCT  
			Chart Chart,
			Org Org,
			Org2 OrgR
			--,Name2 OrgR_Name
		FROM 
			FISDataMart.dbo.OrganizationsV Orgs 
		WHERE 
			Year = ' + Convert(varchar(4), @FiscalYear) + ' AND Period = ''--''
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
Select @TSQL = 'INSERT INTO OrgXOrgR
	(Chart, Org, OrgR/*, OrgR_Name*/
	)
SELECT DISTINCT
			Chart Chart,
			Org Org,
			Org3 OrgR
			--,Name3 OrgR_Name
		FROM 
			FISDataMart.dbo.OrganizationsV Orgs 
		WHERE 
			Year = ' + Convert(varchar(4), @FiscalYear) + ' AND Period = ''--''
			AND Chart1 = ''L'' AND Org1 = ''AAES''
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
	*/

--Programmatic subsitutions:
--Reviewed [12/20/05] MLR: added additional orgs we missed before, separated into different classes of substitution types
-- [12/20/2010] by kjt: Commented this out because this functionality has been incorporated into a new view OrgXOrgR instead.

/*
--By Org code:
	-- lev 5 org which reports separately
Select @TSQL = 'update OrgXOrgR set OrgR = ''CABA'' where Org=''CABA'';
'
	-- lev 2 Orgs with null org_3	
Select @TSQL += 'update OrgXOrgR set OrgR = ''ADNO'' where Org IN (''AADM'',''ACWU'',''AADM'',''AGAD'',''APRV'');
'
	-- lev 2 org, associated with startup of APLS dept. [12/20/05] Tue
Select @TSQL += 'update OrgXOrgR set OrgR = ''APLS'' where Org=''APSC'';
'

--By OrgR determined above, lev 3 Orgs which are not reported on separately:
	--	lev 3 Orgs
Select @TSQL += 'update OrgXOrgR set OrgR = ''ADNO'' where OrgR IN (''AHIS'',''AWRD'',''GRCP'');
'
Select @TSQL += 'update OrgXOrgR set OrgR = ''AEDS'' where OrgR=''ALAR'';
'
Select @TSQL += 'update OrgXOrgR set OrgR = ''AHCD'' where OrgR=''AHCH'';
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

/*
original using DECODE: (abandoned because I didn't want nulls in Org3 for AAES level 1, 2 Orgs
INSERT INTO OrgXOrgR
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
10/11/05] Tue 
	Created. Returns 897 + 55 + 344 rows, respectively. (couple of seconds)
10/12/05] Wed
	Modified to do OrgR re-assignements (e.g. CABA)
	Modified to go against explicit year in FINANCE.ORGANIZATION_HIERARCHY (hard-coded).
		Note: this changed execution time from 2 to 12 seconds.
	Added additional OrgR substitution codes other than CABA. (More still needed)
[10/5/06] Thu
	Just takes a second or two to run. Output screen:
(1453 row(s) affected)	--drop
(1007 row(s) affected)	--AAES Cht3
(6 row(s) affected)		--AAES Cht2
(72 row(s) affected)	--Biosci
(368 row(s) affected)	--Cooperative Extension
(1 row(s) affected)
(4 row(s) affected)
(1 row(s) affected)
(10 row(s) affected)
(2 row(s) affected)
(48 row(s) affected)

[01/13/2010]
	Revised to use FISDataMart vs Campus Data Warehouse (FIS_DS) and Open Query.
	
[12/17/2010] by kjt:
	Revised to use OrganizationsV view instead of Organizations table.

[12/20/2010] by kjt: Commented all of the above except for the delete statements, because 
this functionality can now be done with a single select statement using the new OrganizationsV view.

[12/20/2010] by kjt: Commented out the OrgR updating because this functionality has been
 incorporated into a new view OrgXOrgR instead.

-------------------------------------------------------------------------
 USAGE:

	
	EXEC usp_Repopulate_OrgXOrgR @FiscalYear, [@IsDebug]

*/
