-- =============================================
-- Author:		Ken Taylor
-- Create date: 02/04/2010
-- Description:	This script populates the AD-419
-- database for the Fiscal Year provided.
-- Modifications: 
-- 2010-11-17 by kjt: Added call to execute sp_Set_ACBS_PPS_Expenses_To_BIOS_Orgs,
-- and call to execute sp_Delete_AD419_204_Expenses_After_Identificaion.
--
-- 2010-12-17 by kjt: Removed call to execute sp_Set_ACBS_PPS_Expenses_To_BIOS_Orgs,
-- as this org remapping is now being done in the Expenses view.
--
-- 2011-11-21 by kjt: Added changes to account for AHCE org consolidations.
--	Added call to run sp_Adjust241FTE as per Steve Pesis.
-- 2012-11-05 by kjt: Commented out portion of code that handles populating raw PPS expenses since TOE is no
--	longer available, and we need to populate them using a different longer-running technique.
-- 2012-11-19 by kjt: Revised logic to set nocount ON if @IsDebug = 1.
-- 2012-11-21 by kjt: Added logic to handle this year's project anomalies, specifically in regards to SFN expenses.
-- 2013-11-08 by kjt: Commented out part that updated Titles table as this did not work with synonyms.
--	The statements will need to be run directly against the PPS DataMart Titles tables referenced by the synonym.
--	Also rewrote the "Secondly, update the accession numbers where the quad numbers match:" section to do 
-- a better join as the former one was returning multiple results from the sub query.
-- 2013-11-12 by kjt: Added call to usp_RepopulateProjXOrgRForIntedepartmentalProjects to automatically
-- add interdepartmental projects to ProjXOrgR:
-- 2013-11-13 by kjt: Removed  @FiscalYear parameter from EXEC @return_value = usp_UpdateLaborTransactionsMissingEmployeeNames 
--	as it was not needed and failed because too many parameters were provided otherwise.
-- 2013-11-13 by kjt: Added logic to determine if LaborTransactions table needs to be reloaded automatically 
-- instead of having to remember to uncomment and comment out statement block the first time the sproc is
-- run for the current AD-419 reporting year.
-- 2014-12-29 by kjt: Added logic to call usp_DropAndReCreateExpensesViewForFiscalYear, which handles re-creating
-- the Expenses (view) for the particular FiscalYear so that the correct join is made across the ArcCodeExclusions for 
-- the matching Fiscal Year..  This view also handles remapping CABA expenses to ADNO, BGEN expenses to BMCB, and
-- BCPB expenses to BEVE.
-- Also added the SQL statement to delete all of the expenses for 'ABML', 'AFDS', 'ALAB', and 'USDA' (line 599).
-- 2015-02-25 by kjt: Removed [AD419] specific database references so sproc could be used on other databases
-- such as AD419_2014, etc.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_All] 
( 
	@FiscalYear int = 2009,		--This is the FiscalYear of the reporting period to generate.
	@BeginDate varchar(16) = '',-- The beginning of the fiscal year, i.e. for FY 2009: 2008.07.01, etc.
	@IsDebug bit = 0			-- Set this to 1 to create a listing of all the SQL to be run, but not execute.
 )
AS
BEGIN

--declare @FiscalYear int = 2009 -- This is the FiscalYear of the reporting period to generate.
--declare @BeginDate varchar(16) = '' -- The beginning of the fiscal year, i.e. for FY 2009: 2008.07.01, etc.
--declare @IsDebug bit = 0 -- Set this to 1 to create a listing of all the SQL to be run, but not execute.

-- This is the temp table name to help with automating the classification of the SFN entries. 
declare @TableName varchar(50) = 'FFY_' + Convert(char(4), @FiscalYear) + '_SFN_ENTRIES'
declare @TSQL varchar(max) = '' 
DECLARE	@return_value int

-- Set the beginning date of the UCD FiscalYear:
-- Note if the FiscalYear is 2008-2009 then the UCD FiscalYear will be 2009
-- Therefore, the beginning date of 2008-2009 fiscal year will be 2008.07.01, etc.
-- This variable is used later by the sp_Extract_Raw_PPS_Expenses script.
IF @BeginDate = ''
	BEGIN
		Select @BeginDate = Convert(char(4),(@FiscalYear - 1)) + '.07.01'
	END

IF @IsDebug = 1
	SET NOCOUNT ON
	
-- First we update the OrgXOrgR table:
EXEC @return_value = usp_Repopulate_OrgXOrgR
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- Before running the next part of the update process the following tables must be loaded from data 
-- provided by Steve and Co.
-- 1. [dbo][Projects] Note to delete all data from the table before beginning.
-- 2. [FISDataMart].[dbo].[ARCCodes]

-- After loading the projects table we update the ProjXOrgR table:
EXEC @return_value = [usp_RepopulateProjXOrgR]
SELECT	'Return Value' = @return_value

-- After populating projects and repopulating the ProjXOrgR table, we set the Interdepartmental Flag 
EXEC @return_value = usp_setInterdepartmentalFlag
SELECT	'Return Value' = @return_value

-- After completing the above, we begin the main load process: 

-- This step has been replaced by sp_RePopulate_NonSalary_Expenses_Using_ARC (see below)
--EXEC @return_value = sp_RePopulate_CAES_Expenses_Using_ARC
--	 @FiscalYear = @FiscalYear,
--	 @IsDebug = @IsDebug
--SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_Acct_SFN 
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- New Step added 2012-11-19 by kjt:
-- Update Acct_SFN's 204s to 219:
UPDATE [dbo].[Acct_SFN]
SET	   [SFN] = '219' 
      ,[SFNsCt] = 1
      ,[SFNs] = '219'
WHERE [SFN] LIKE '204%'

-- 2013-11-08 by kjt: Commented out update Titles table as this did not work with synonyms.
-- It will need to be run directly from the PPS DataMart Titles tables referenced by the synonym.
---- 2012-11-19 by kjt:
---- Add some title code StaffTypes that were formerly null:
---- SFN 241
--update [PPSDataMart].[dbo].[Titles]
--set StaffType = '1S'
--WHERE TitleCode IN (
--'3200',
--'3203',
--'3205',
--'3206',
--'3210',
--'3213',
--'3215',
--'3220',
--'3223',
--'3225'
--)

----SFN 243
--update [PPSDataMart].[dbo].[Titles]
--set StaffType = '3T'
--WHERE TitleCode IN (
--'9293',
--'9528'
--)

--Revised this step to load the labor transactions table as a datasource for sp_Extract_Raw_PPS_Expenses
-- 2013-11-13 by kjt: Added logic to determine if table needs to be reloaded automatically 
-- instead of having to remember to uncomment and comment out statement block the first time the sproc is
-- run for the current AD-419 reporting year.
DECLARE @NeedsReload bit

EXEC	@return_value = [dbo].[usp_CheckIfLaborTransactionsTableReloadIsRequired]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug,
		@NeedsReload = @NeedsReload OUTPUT
SELECT	@NeedsReload as N'@NeedsReload'

IF @NeedsReload = 1
	BEGIN
		EXEC @return_value = usp_LoadLaborTransactions 
			 @FiscalYear = @FiscalYear, 
			 @IsDebug = @IsDebug
		SELECT	'Return Value' = @return_value

		EXEC @return_value = usp_UpdateLaborTransactionsMissingEmployeeNames 
			 @IsDebug = @IsDebug
		SELECT	'Return Value' = @return_value
	END

EXEC @return_value = sp_Extract_Raw_PPS_Expenses 
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

--Revised this step to use the new format of the Raw_PPS_Expenses table, since Salary and Benefits are now combined.
EXEC @return_value = sp_Repopulate_Expenses_PPS
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_PPS_Expenses
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- New Step; replaces sp_RePopulate_CAES_Expenses_Using_ARC.  It excludes the object consolidation codes 
-- and TransDocTypes that were picked up in the labor transactions table.
-- Populate the FIS Non-Salary Expenses
EXEC @return_value = sp_RePopulate_NonSalary_Expenses_Using_ARC
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_FIS_Expenses
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- Next 2 steps are no longer needed because 204 expenses are being handled as SFN 219 expenses.
--EXEC @return_value = sp_Repopulate_AD419_204
--	 @FiscalYear = @FiscalYear, 
--	 @IsDebug = @IsDebug
--SELECT	'Return Value' = @return_value

--EXEC @return_value = sp_Repopulate_AD419_204_Expenses 
--	 @FiscalYear = @FiscalYear, 
--	 @IsDebug = @IsDebug
--SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_219_Expenses 
	 @FiscalYear = @FiscalYear, 
	 @ConvertExpensesWithNullAccessionNumbers = 0,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- Note: The above scripts are modified versions of the ones Scott used in previous years.

-- This is the script I ran on donbot:

-- The following scripts are new ones that I created to help automate the insertion of
-- the 20x (201, 202, and 205), 22F, and CE expenses, so that the accounting team does
-- not need to enter them from the AD-419 application's Administration UI.

-- Create the FFY_2xxx_SFN_ENTRIES table and insert the FFY 2xxx 201 expenses:

EXEC	@return_value = [dbo].[sp_GET_FFY_201_EXPENSES]
		@FiscalYear = @FiscalYear, -- The table name is based on the Fiscal Year provided.
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- insert the FFY 2xxx 202 Expenses
--DECLARE	@return_value int
EXEC	@return_value = [dbo].[sp_GET_FFY_202_EXPENSES]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- insert the FFY 2xxx 205 Expenses
--DECLARE	@return_value int
EXEC	@return_value = [dbo].[sp_GET_FFY_205_EXPENSES]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- Create the SFN_PROJECT_QUAD_NUM table and insert records
-- for the projects that still have null accession numbers
-- using the Projects table as the source for matching:

If @IsDebug = 1
	Begin
		Print 'IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[SFN_PROJECT_QUAD_NUM]'') AND type in (N''U'')) 
	DROP TABLE [SFN_PROJECT_QUAD_NUM]
'
	End
Else
	Begin
		IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[SFN_PROJECT_QUAD_NUM]') AND type in (N'U')) 
	DROP TABLE [SFN_PROJECT_QUAD_NUM]

	End
	
--DECLARE	@return_value int, @FiscalYear int = 2013, @IsDebug bit = 0
EXEC	@return_value = [dbo].[sp_GET_QUAD_NUM_WITH_NULL_ACCESSION]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- Now update the quad numbers in the [FFY_2xxx_SFN_ENTRIES] table
-- where the accession number is null:
-- 2012-11-21 by kjt: Revised logic to handle cases where award number has no asterisk and no trailing dash-number,
-- and handle assigning quad-num to weird project with AwardNum: NRSP008
-- DECLARE @TableName varchar(50) = 'FFY_2013_SFN_ENTRIES', @TSQL varchar(MAX) = '', @IsDebug bit = 0
 Select @TSQL = 'update [dbo].[' + @TableName + '] 
 set QuadNum = CASE 
			--WHEN SUBSTRING(AwardNum, 11, 4) NOT LIKE ''%-'' THEN  SUBSTRING(AwardNum, 11, 4)
			--ELSE SUBSTRING(AwardNum, 10, 4)
			WHEN AwardNum LIKE ''NRSP008'' THEN ''5929''
			WHEN AwardNum LIKE ''CA-D*-LAW-6673-H'' THEN  ''2085''
			WHEN CONVERT(int, SUBSTRING(AwardNum, 10, 4)) > 0 THEN SUBSTRING(AwardNum, 10, 4)
			ELSE SUBSTRING(AwardNum, 11, 4)
		 END
 where Accession is null;
 '
 If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End

 -- Secondly, update the accession numbers where the quad numbers match:
 --DECLARE @TableName varchar(50) = 'FFY_2013_SFN_ENTRIES', @TSQL varchar(MAX) = '', @IsDebug bit = 0
 --Select @TSQL = 'update [dbo].[' + @TableName + ']  
 --set  Accession = (
	--select distinct quadnum.Accession
	--from [dbo].[SFN_PROJECT_QUAD_NUM] quadnum
	--where [' + @TableName + '].QuadNum = quadnum.QuadNum
	
 --)
 --where Accession is null;
 --'

 Select @TSQL = 'update[dbo].[' + @TableName + ']  
 set  Accession = quadnum.Accession
 FROM [dbo].[' + @TableName + ']  
 INNER JOIN [dbo].[SFN_PROJECT_QUAD_NUM] quadnum
 ON [' + @TableName + '] .QuadNum = quadnum.QuadNum
 where [' + @TableName + '].Accession is null'

  If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End
	
  -- set the IsActive bit according to whether or not a match was found
  -- by joining against the projects table:
  -- 2012-11-21 by kjt: Changed WHERE Accession is null to WHERE IsActive is null as desired.
  Select @TSQL = 'UPDATE [dbo].[' + @TableName + ']
  SET [IsActive] = CASE WHEN Accession is not null THEN 1
				   ELSE 0 END
  WHERE IsActive is null;
  '
  If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End
	
-- Set the OrgR appropriately for non-complying orgs:
Select @TSQL = '
update [dbo].[' + @TableName + '] set OrgR = ''CABA'' where Org = ''CABA'';
update [dbo].[' + @TableName + '] set OrgR = ''ADNO'' where Org IN (''AADM'',''ACWU'',''AADM'',''AGAD'',''APRV'');
update [dbo].[' + @TableName + '] set OrgR = ''APLS'' where Org = ''APSC'';
update [dbo].[' + @TableName + '] set OrgR = ''ADNO'' where OrgR IN (''AHIS'',''AWRD'',''GRCP'');
-- Changes do to AHCE and AENM consolidations:
--update [dbo].[' + @TableName + '] set OrgR = ''AEDS'' where OrgR = ''ALAR'';
--update [dbo].[' + @TableName + '] set OrgR = ''AHCD'' where OrgR = ''AHCH'';
update [dbo].[' + @TableName + '] set OrgR = ''AHCE'' where OrgR IN (''AHCD'', ''AHCH'', ''AEDS'', ''ALAR'');

-- 2012-11-21 by kjt: Switch of expenses for Williamson.  She switched depts., from ENM to PPA, last May as per Alyssa Gartung.
update [dbo].[' + @TableName + '] set OrgR = ''APPA'' where Org = ''VMWN'';
'
If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End

-- This step will now attempt to insert all of the resulting 20x values into the expenses table: 
--DECLARE	@return_value int 
EXEC	@return_value = [dbo].[sp_INSERT_20x_EXPENSE_SUMS_INTO_EXPENSES]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- This step changes all the expense records with an account # of 'AGARGAA' to have an
-- OrgR of 'AIND' so that they can show up under department AIND and can be associated
-- from the UI:

EXEC	@return_value = [dbo].[sp_Associate_AD419_IND_with_AIND]
		@IsDebug = @IsDebug

/*
The following manual step is no longer required because I modified the sproc to change
the OrgR of any records that already have their accession numbers in the ProjXOrgR table
and an OrgR of AIND, from whatever they are, probably ADNO or AGAD, to AIND and insert
into the expenses table using AIND as the OrgR as opposed to AGAD, ADNO (or whatever).

-- This last part required manual intervention from Steve because these 2 records
-- had unmatched Accession/OrgR in the ProjXOrg table.  Therefore AGAD/ADNO needed to 
-- be changed to AIND.  
-- Note: We could automate this set if changing AGAD to AIND is going to be a typical occurance. 
-- Therefore, this piece would be manual; however, since we already figured what needed
-- to be changed I just added it to the script so that the entire load process could be 
-- re-ran with the same results. 

-- Steve gave me this info as well regarding changing AGAD to AIND, plus 
-- reassigning some of the accession numbers.
  
  Select @TSQL = 'EXEC dbo.usp_insertProjectExpense ''201'', ''AIND'', ''0194861'', 1590.84
  EXEC dbo.usp_insertProjectExpense ''202'', ''AIND'', ''0209115'', 3405.14'
  
  If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End
  */
-- After loading the FieldStationExpensesImport table from the spreadsheet run the following to insert
-- records into the Expenses_Field_Stations table:

  TRUNCATE TABLE [dbo].[Expenses_Field_Stations] 

  INSERT INTO [dbo].[Expenses_Field_Stations] (
	   [Org_R]
      ,[Accession]
      ,[Expense]
      ,[Project_Leader]
  )
  SELECT     
	 [OrgR]
	,[Accession_#]
	,[Field Station Charge (Line 22F)]
	,[Investigator]
  FROM [dbo].[FieldStationExpensesImport]
  INNER JOIN [dbo].[ReportingOrg] ON Dept_Code = CRISDeptCd

-- After loading the Expenses_Field_Stations table from the spreadsheet run the following to insert
-- the 22F expenses into the Expenses table:

--DECLARE @return_value int, @FiscalYear int = 2013, @IsDebug bit = 0 
	EXEC	@return_value = [dbo].[sp_INSERT_22F_EXPENSES_INTO_EXPENSES]
			@FiscalYear = @FiscalYear,
			@IsDebug = @IsDebug

	SELECT	'Return Value' = @return_value
	
-- After loading the CES_List_2009 (or similar) table from the spreadsheet run the following to insert
-- the CE expenses into the CESList and CESXProjects tables:
	declare @CESTableName varchar(50) = 'CES_List_' + Convert(char(4), @FiscalYear)
	EXEC	@return_value = [dbo].[sp_INSERT_CE_EXPENSES_INTO_CESXProjects]
			@FiscalYear = @FiscalYear,
			@TableName = @CESTableName,
			@IsDebug = @IsDebug
			
-- Once the sp_INSERT_CE_EXPENSES_INTO_CESXProjects script has completed running, run the 
-- following to insert the CE expenses into the Expenses table:
	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_CE]
			@FiscalYear = @FiscalYear,
			@IsDebug = @IsDebug

	SELECT	'Return Value' = @return_value
	

--2012-11-19 by kjt:
-- Steve wants to keep the 204 expenses, but handle them as 219 expenses.
---- 2010-11-17 by kjt:
---- New requirement for 2009-2010 onward: Delete all 204 expenses:
--	EXEC	@return_value = [dbo].[sp_Delete_AD419_204_Expenses_After_Identification]
--			@FiscalYear = @FiscalYear,
--			@IsDebug = @IsDebug

--	SELECT	'Return Value' = @return_value
	
-- 2011-11-21 by kjt:
-- Added call to run sp_Adjust241FTE as per Steve Pesis because the 241 count was lower than last year.
EXEC	@return_value = [dbo].[sp_Adjust241FTE]
SELECT	'Return Value' = @return_value

-- 2012-2013 by kjt:
-- Added call to usp_RepopulateProjXOrgRForIntedepartmentalProjects to automatically
-- add interdepartmental projects to ProjXOrgR as opposed to operating on a hard-coded list.  
-- Make sure you update CoopDepts field in the AllProjects table on all interdepartmental projects prior to running!!!!!
EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects]
		@DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

/*
-- 2012-2013 by kjt:
-- The following block has been replaced with USP: usp_RepopulateProjXOrgRForIntedepartmentalProjects
-- effective Reporting Year 2012-2013.  See above.

-- 2011-2012 by kjt: 
-- Delete all the interdepartment projects from ProjXOrgR and 
-- re-insert all the interdepartment projects into ProjXOrgR
-- because all of them were not inserted automatically:

delete FROM [dbo].[ProjXOrgR]
  where accession in
  (
  '0188218',
'0224414',
'0204211',
'0215031',
'0221560',
'0177567',
'0174108',
'0223471',
'0200381',
'0177959',
'0224085',
'0192081',
'0216265',
'0222926',
'0198050',
'0207125'
  )

 --2012-2013 by kjt: Above should probably be delete from table where
 --accession selected from project where isInterdepartmental = 1:

  insert into [dbo].[ProjXOrgR]
  values 
('0174108','APLS'),('0174108','BMCB'),
('0177567','AETX'),('0177567','AENM'),
('0177959','APLS'),('0177959','ALAW'),
('0188218','AETX'),('0188218','ANUT'),
('0192081','BPLB'),('0192081','APLS'),
('0198050','AANS'),('0198050','AETX'),
('0200381','ANUT'),('0200381','AETX'),
('0204211','AENM'),
('0207125','AANS'),('0207125','AETX'),
('0215031','AARE'),('0215031','ADES'),
('0216265','AHCE'),('0216265','ADES'),
('0221560','AARE'),('0221560','ADES'),
('0222926','ABAE'),('0222926','APLS'),
('0223471','AHCE'),('0223471','AVIT'),
('0224085','ANUT'),('0224085','AFST'),
('0224414','ANUT'),('0224414','AETX');

--2012-2013 by kjt: Above should be replaced by parsing routine that uses CoopDepts field from AllProjects
 --table. 
*/

/*
-- The following step is no longer required because the expenses are already present and have had
-- their OrgR changed to AIND so that they could be associated from the UI.
--
-- Plus run the sp_Repopulate_AD419_IND sproc, which will insert any records that have and OrgR of
-- 'ANID' into the expenses table:
	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_IND]
			@IsDebug = @IsDebug

	SELECT	'Return Value' = @return_value
*/

-- 2014-12-329 by kjt:
-- New for 2014 and going forward:
-- Prior to allowing UI access to the expenses data, the new expense view must be created
-- that filters out any ARC exclusions precent in the ARC exclusions table for
-- the current reporting period, i.e. Fiscal Year.  This is done by calling the
-- new stored procedure: usp_DropAndReCreateExpensesViewForFiscalYear.

EXEC	@return_value = [dbo].[usp_DropAndReCreateExpensesViewForFiscalYear] 
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- That's it!  You've completed the AD-419 dataset load procedure!

-- Post association; pre report generation:
--
/*
2014-12-29 by kjt: This portion is no longer required because the 204 expenses 
are being handled as 219 expenses, and the CE expenses are being auto-associated
by the program.  However, I am leaving the comments for historical purposes.

-- Old update: After Steve finishes associating the 204 and CE expenses from the UI, 
-- you'll need to re-run the 
-- sp_Repopulate_AD419_204_Expenses and sp_Repopulate_AD419_CE scripts,
-- plus the new [sp_Repopulate_AD419_219_Expenses] @FiscalYear = 2009, @ConvertExpensesWithNullAccessionNumbers = 1
-- script.
-- I found it also necessary to re-run sp_INSERT_22F_EXPENSES_INTO_EXPENSES as not
-- all of the 22F expenses seemed to be showing up.  This could happen if some additional
-- ones were added/associated from the UI after the sproc was run the first time.
*/

/*
2014-12-29 by kjt: This portion is no longer because CABA no longer has a 
director; therefore, the expnses are being pro-rated along with the ADNO
administrative expenses as per Shannon T.
Therefore, it makes more seems more appropriate to simply delete the 
expenses that have an OrgR of ABML, AFDS, ALAB, and USDA at this point
so that all that is left to do is make the associations and generate the 
final reports.

-- Lastly, run sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS. For this last script, you must verify
-- the Account, typically 0067546, and the OrgR, typically ABAE, before running it.
-- sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS zeros out and negative sums AND
-- changes the association OrgR from CABA to ABAE,
-- plus updates the corresponding expense's "isAssociated" bit to 1.
-- This sproc also deletes any unassociated expense that have an OrgR of ABML, AFDS, ALAB, and USDA.
*/

-- 2014-12-29 by kjt: 
-- Since deleting any expenses that had an OrgR of ABML, AFDS, ALAB, or USDA
-- was formerly handled by the call to sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS,
-- which is no longer being called, I am added a manual statement to handle
-- the deletion of those expenses at this point as opposed to after all of the
-- associations have been made:
SELECT @TSQL = '
	DELETE from AllExpenses where isAssociated = 0 AND OrgR in (''ABML'', ''AFDS'', ''ALAB'', ''USDA'')
'
IF @IsDebug = 1
	PRINT @TSQL
ELSE
	EXEC(@TSQL)

END
