-- =============================================
-- Author:		Ken Taylor
-- Create date: November 26, 2014
-- Description:	Truncate the AD419 database tables to allow reloading of expenses and making associations.
-- Note that you will also need to truncate additional tables to do a total reload for the next fiscal year. 
-- Usage:
/*
	-- Initial run for new reporting period:
	EXEC [dbo].[usp_TruncateTablesForReload] @FiscalYear = 2015, @TruncateImportTables = 1, @IsDebug = 0


	-- Subsequent run(s) for same reporting period:
	EXEC [dbo].[usp_TruncateTablesForReload] @FiscalYear = 2015, @TruncateImportTables = 0, @IsDebug = 0

*/
-- Modifications:
--	 20160818 by kjt: Added TruncateImportTables feature.  Fixed missing "--" in front of comment.
--	 20160820 by kjt: Removed truncate of labor transactions.
-- =============================================
CREATE PROCEDURE [dbo].[usp_TruncateTablesForReload] 
	@FiscalYear int = 2015, -- The later portion of the AD-419 reporting year, i.e. 2014 for 2013-2014, etc.
	@TruncateImportTables bit = 1,  -- Set to 1 if you also want to truncate all the import tables and start from scratch.
	@IsDebug bit = 0 -- Set to 1 to print SQL created by this procedure only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''

	IF @TruncateImportTables = 1
	BEGIN
		SELECT @TSQL = '
USE AD419

truncate table CFDANumImport
--truncate table AllProjectsImport -- No longer used.  Projects are imported directly into AllProjectsNew
truncate table AllProjectsNew
truncate table Project
truncate table InterdepartmentalProjectsImport
truncate table CesListImport
truncate table FieldStationExpenseListImport
truncate table ExpiredProjectCrossReference
'
	END

	SELECT @TSQL += '
--truncate table DaFIS_AccountsByARC --Auto truncated upon reload
--truncate table UFY_FFY_FIS_Expenses --Auto truncated upon reload

--truncate table  AllAccountsFor204Projects --Truncated upon reload
truncate table [204AcctXProj]  -- Data from here is what''s displayed in the AD-419 App

truncate table [dbo].[FIS_ExpensesFor204Projects] -- auto truncate upon reload
truncate table [dbo].[PPS_ExpensesFor204Projects] -- auto truncate upon reload

truncate table Missing204AccountExpenses --auto truncate upon reload

truncate table Acct_SFN
truncate table NewAccountSFN -- auto truncate

truncate table Associations --yes; otherwise, residual associations show up in UI

truncate table dbo.CESList 

truncate table CESXProjects -- yes; otherwise, residual expenses show up in UI

--truncate table FieldStationExpenseListImport

truncate table AllExpenses -- yes: otherwise residual expenses show up in UI

--truncate table dbo.Expenses_CAES --table no longer used
truncate table [dbo].[FIS_ExpensesForNon204Projects] -- auto-truncate 

--truncate table Expenses_CE_Nonsalary

truncate table [dbo].[PPS_ExpensesForNon204Projects] -- auto-truncate upon reload
--truncate table Expenses_PPS

truncate table ProjXOrgR -- yes; repopulate after all projects and interdepartmental project have been loaded

--truncate table [dbo].[AnotherLaborTransactions] -- Auto truncate upon reload
--truncate table Raw_PPS_Expenses --Table no longer used

truncate table FFY_SFN_Entries --Auto-truncate upon load

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[SFN_PROJECT_QUAD_NUM]'') AND type in (N''U'')) 
	DROP TABLE [SFN_PROJECT_QUAD_NUM] -- table no longer used

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[FFY_' + CONVERT(varchar(4), @FiscalYear) + '_SFN_ENTRIES]'') AND type in (N''U'')) 
	DROP TABLE [FFY_' + CONVERT(varchar(4), @FiscalYear) + '_SFN_ENTRIES] -- table no longer used
'

IF @IsDebug = 1
BEGIN
	PRINT @TSQL
END
ELSE
	EXEC(@TSQL)

END