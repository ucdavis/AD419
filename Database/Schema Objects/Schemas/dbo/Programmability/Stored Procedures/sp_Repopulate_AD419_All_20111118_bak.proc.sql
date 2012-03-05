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
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_All_20111118_bak] 
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
	
-- First we update the OrgXOrgR table:
EXEC @return_value = usp_Repopulate_OrgXOrgR
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- Before running the next part of the update process the following tables must be loaded from data 
-- provided by Steve and Co.
-- 1. [AD419].[dbo][Projects] Note to delete all data from the table before beginning.
-- 2. [FISDataMart].[dbo].[ARCCodes]

-- After loading the projects table we update the ProjXOrgR table:
EXEC @return_value = [usp_RepopulateProjXOrgR]
SELECT	'Return Value' = @return_value

-- After populating projects and repopulating the ProjXOrgR table, we set the Interdepartmental Flag 
EXEC @return_value = usp_setInterdepartmentalFlag
SELECT	'Return Value' = @return_value

-- After completing the above, we begin the main load process: 

EXEC @return_value = sp_RePopulate_CAES_Expenses_Using_ARC
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_Acct_SFN 
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Extract_Raw_PPS_Expenses 
	 @FiscalYear = @FiscalYear, 
	 @BeginDate = @BeginDate, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_Expenses_PPS
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_PPS_Expenses
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_FIS_Expenses
	 @FiscalYear = @FiscalYear,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_204
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_204_Expenses 
	 @FiscalYear = @FiscalYear, 
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

EXEC @return_value = sp_Repopulate_AD419_219_Expenses 
	 @FiscalYear = @FiscalYear, 
	 @ConvertExpensesWithNullAccessionNumbers = 0,
	 @IsDebug = @IsDebug
SELECT	'Return Value' = @return_value

-- Note: The above scripts are modified verisons of the ones Scott used in previous years.

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
	
--DECLARE	@return_value int
EXEC	@return_value = [dbo].[sp_GET_QUAD_NUM_WITH_NULL_ACCESSION]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug

SELECT	'Return Value' = @return_value

-- Now update the quad numbers in the [FFY_2xxx_SFN_ENTRIES] table
-- where the accession number is null:

 Select @TSQL = 'update [AD419].[dbo].[' + @TableName + '] 
 set QuadNum = CASE 
			WHEN SUBSTRING(AwardNum, 11, 4) NOT LIKE ''%-'' THEN  SUBSTRING(AwardNum, 11, 4)
			ELSE SUBSTRING(AwardNum, 10, 4)
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
 Select @TSQL = 'update [AD419].[dbo].[' + @TableName + ']  
 set  Accession = (
	select distinct quadnum.Accession
	from [AD419].[dbo].[SFN_PROJECT_QUAD_NUM] quadnum
	where [' + @TableName + '].QuadNum = quadnum.QuadNum
	
 )
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
	
  -- set the IsActive bit according to whether or not a match was found
  -- by joining against the projects table:
  
  Select @TSQL = 'UPDATE [AD419].[dbo].[' + @TableName + ']
  SET [IsActive] = CASE WHEN Accession is not null THEN 1
				   ELSE 0 END
  WHERE Accession is null;
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
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''CABA'' where Org = ''CABA'';
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''ADNO'' where Org IN (''AADM'',''ACWU'',''AADM'',''AGAD'',''APRV'');
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''APLS'' where Org = ''APSC'';
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''ADNO'' where OrgR IN (''AHIS'',''AWRD'',''GRCP'');
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''AEDS'' where OrgR = ''ALAR'';
update [AD419].[dbo].[' + @TableName + '] set OrgR = ''AHCD'' where OrgR = ''AHCH'';
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
  
  Select @TSQL = 'EXEC AD419.dbo.usp_insertProjectExpense ''201'', ''AIND'', ''0194861'', 1590.84
  EXEC AD419.dbo.usp_insertProjectExpense ''202'', ''AIND'', ''0209115'', 3405.14'
  
  If @IsDebug = 1
	Begin
		Print @TSQL
	End
 Else
	Begin
		Exec(@TSQL)
	End
  */
-- After loading the Expenses_Field_Stations table from the spreadsheet run the following to insert
-- the 22F expenses into the Expenses table:
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
	
	
-- 2010-11-17 by kjt:
-- New requirement for 2009-2010 onward: Delete all 204 expenses:
	EXEC	@return_value = [dbo].[sp_Delete_AD419_204_Expenses_After_Identification]
			@FiscalYear = @FiscalYear,
			@IsDebug = @IsDebug

	SELECT	'Return Value' = @return_value
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
	
-- That's it!  You've completed the AD-419 dataset load procedure!

-- Post association; pre report generation:
--
-- Update: After Steve finishes associating the 204 and CE expenses from the UI, 
-- you'll need to re-run the 
-- sp_Repopulate_AD419_204_Expenses and sp_Repopulate_AD419_CE scripts,
-- plus the new [sp_Repopulate_AD419_219_Expenses] @FiscalYear = 2009, @ConvertExpensesWithNullAccessionNumbers = 1
-- script.
-- I found it also necessary to re-run sp_INSERT_22F_EXPENSES_INTO_EXPENSES as not
-- all of the 22F expenses seemed to be showing up.  This could happen if some additional
-- ones were added/associated from the UI after the sproc was run the first time.
-- Lastly, run sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS. For this last script, you must verify
-- the Account, typically 0067546, and the OrgR, typically ABAE, before running it.
-- sp_INSERT_CABA_EXPENSES_INTO_ASSOCIATIONS zeros out and negative sums AND
-- changes the association OrgR from CABA to ABAE,
-- plus updates the corresponding expense's "isAssociated" bit to 1.
-- This sproc also deletes any unassociated expense that have an OrgR of ABML, AFDS, ALAB, and USDA.
END
