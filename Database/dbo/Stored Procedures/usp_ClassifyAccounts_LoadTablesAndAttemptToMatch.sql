
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 19, 2016
-- Description:	Load AllAccountsFor204Projects, and NewAccountSFN.  
-- Classify Accounts with their corresponding SFNs, 
-- and AD419Accounts.
-- Load FFY_SFN_Entries, and attempt to automatically
-- match 20x accounts to their corresponding projects.
-- Lastly, load AnotherLaborTransactions so that the FTE reports 
-- can be reviewed and either accepted or the DOS Codes, Financial
-- Doc Type Code, and Consolidations Codes modified, and the 
-- reports re-ran.
--
-- Usage:
/*
	EXEC usp_ClassifyAccounts_LoadTablesAndAttemptToMatch @FiscalYear = 2016, @IsDebug = 0
*/
--
-- Modifications:
--	2016-08-20 by kjt: Added logic to ignore any 204 projects that have expenses less
--		than $100.  These will need to "un-ignored" once the departments have
--		completed their associations.
--	2016-08-22 by kjt: Added logic to set XXX project's OrgR to 'AINT'.
--  2016-09-06 by kjt: Added logic to populate ProcessStatus and ProcessCategory.
--	2016-09-20 by kjt: Added RAISE ERROR statements to return user-generated exceptions back to caller.
--	2016-09-22 by kjt: Commented out manual update of IsExpired and OrgR for interdepartmental projects as
--		this is now done in ProjectImportService c# code.
--	2016-11-07 by kjt: Revised to pass FiscalYear to usp_RepopulateProjXOrgR.
--	2016-12-16 by kjt: Fixed issue for handling setting project's IsIgnored flag for projects with NULL expenses totals.
--	2017-01-18 by kjt: Removed temporary fixes which had been commented out.
--	2017-09-10 by kjt: Commented out the logic to load the ProjXorgR table, and this now needs
--		to be done after the Expenses have been loaded because we're programatically determining
--		the interdepartmental projects.
--	2017-08-17 by kjt: Removed ProjXOrgR and project adjustment and reloading logic.
--	2017-09-26 by kjt: Revised logic to set null expenses totals to 0.
--	2019-10-11 by kjt: Added call to reload OrgR_lookup table prior to reloading AllEmployeeFTE.
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClassifyAccounts_LoadTablesAndAttemptToMatch] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @ErrorMessage varchar(1024) = ''

	DECLARE @AllProjectsCount int = 0
	
	-- First check to see if the AllProjectsNew table has bee loaded:
	SELECT @AllProjectsCount = (
		SELECT Count(*)
		FROM [dbo].[AllProjectsNew]
	)

	IF @AllProjectsCount = 0
		SELECT @ErrorMessage = 'Unable to complete this step because projects have yet to be loaded.  Please load projects and try again.'

	IF @ErrorMessage IS NOT NULL AND @ErrorMessage NOT LIKE ''
	BEGIN
		IF @IsDebug = 1
			PRINT '-- ' + @ErrorMessage + '
'
		IF @IsDebug = 0
		BEGIN
			RAISERROR(@ErrorMessage, 16, 1)
			RETURN -1
		END
	END
	
	SELECT @TSQL = '
	-- LoadAllAccountsFor204Projects:
	-- This must be loaded prior to loading AllAccountsFor204Projects as it uses it to calculate FTE.
	EXEC usp_LoadAllAccountsFor204Projects @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + '

	-- Load NewAccountSFN:
	EXEC usp_LoadNewAccountSFN @FiscalYear  = ' + CONVERT(varchar(4), @FiscalYear) + '

	-- Update NewAccountSFN:  Classify accounts, update Account and OP Fund Award Numbers,
	-- and attempt to auto-match to projects:
	EXEC usp_UpdateNewAccountSFN

	-- Once the NewAccountSFN table has been loaded, and updated;
	-- load the old Acct_SFN table so that AD-419 application will work properly:
	TRUNCATE TABLE [dbo].[Acct_SFN]

	INSERT INTO  [AD419].[dbo].[Acct_SFN] (
		   [chart]
		  ,[acct_id]
		  ,[isCE]
		  ,[org]
		  ,[SFN])
	SELECT Chart, Account, isCE, Org, SFN
	FROM  [AD419].[dbo].[NewAccountSFN]
	GROUP BY Chart, Account, Org, SFN, IsCE
	ORDER BY Chart, Account, Org, SFN, isCE

	-- Load AD419Accounts:
	EXEC usp_LoadAD419Accounts

	-- Load FFY_SFN_Entries, and match 20x accounts to their projects:
	EXEC usp_Load_FFY_SFN_Entries @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + '

	-- Update the FFY_SFN_Entries'' Expenses column so we can use it below for setting the IsIgnored column.
	UPDATE [dbo].[FFY_SFN_Entries] 
	SET [Expenses] = ISNULL(t2.Expenses, 0)
	FROM [dbo].[FFY_SFN_Entries] t1
	INNER JOIN [dbo].[AD419Accounts] t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account

	-- Now that FFY_SFN_Entries and AllAccountsFor204Projects have been loaded;
	-- reload AD-419 application''s 204AcctXProj project:
	EXEC [dbo].[sp_Repopulate_AD419_204] @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	--------------------------------------------------------------------------------------------
	--20191011 by kjt: Added call to reload OrgR_lookup table prior to reloading AllEmployeeFTE,
	-- since the reload OrgR_lookup table is used as a data source for AllEmployeeFTE_v.
	
	EXEC [dbo].[usp_LoadOrgR_Lookup]

	-------------------------------------------------------------------------------------------- 
	-- End Added call to reload OrgR_lookup table.

	-- Load the table used as a datasource for the All Employee FTE Report:
	TRUNCATE TABLE AllEmployeeFTE 

	INSERT INTO AllEmployeeFTE
	SELECT * FROM AllEmployeeFTE_v
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

--	-- Update ProcessStatus adn ProcessCategory:
--	SELECT @TSQL = '
--	UPDATE [dbo].[ProcessStatus]
--	SET IsCompleted = 1 
--	WHERE Id = 8

--	UPDATE [dbo].[ProcessCategory]
--	SET IsCompleted = 1 
--	WHERE Id = 3
--'

--	IF @IsDebug = 1
--		PRINT @TSQL
--	ELSE
--		EXEC(@TSQL)

END