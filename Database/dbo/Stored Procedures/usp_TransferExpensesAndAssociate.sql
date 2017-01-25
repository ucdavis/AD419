-- =============================================
-- Author:		Ken Taylor
-- Create date: August 21, 2016
-- Description:	Transfers expenses from the intermediate
-- tables into Expenses, and makes associations as appropriate.
--
-- Prerequisites:
-- FFY_SFN_Entries must have been loaded,
-- ProjXOrgR must have been loaded,
-- FIS_ExpensesFor204Projects must have been loaded,
-- FIS_ExpensesForNon204Projects must have been loaded,
-- PPS_ExpensesFor204Projects must have been loaded,
-- PPS_ExpensesForNon204Projects must have been loaded,
-- CE Specialists:
--		 CesListImport, Project, and ProjXOrgR must have been loaded.
-- Field Stations Expenses:
--		FieldStationExpenseListImport, Project, and ProjXOrgR must have been loaded.
--
-- Usage:
/*
	EXEC [dbo].[usp_TransferExpensesAndAssociate]
	@FiscalYear = 2016, @IsDebug = 0
*/
-- Modifications:
--	20160914 by kjt: Added RAISE ERROR logic to return user generated exceptions back to caller.
--	20160920 by kjt: Removed calls to load CE Specialists and Field Station Expenses are these now
--		separate steps.
--	20170118 by kjt: Removed commented out calls (above).
-- =============================================
CREATE PROCEDURE [dbo].[usp_TransferExpensesAndAssociate] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ErrorMessage varchar(200) = ''
	IF NOT EXISTS (
		SELECT COUNT(*) FROM [dbo].[FFY_SFN_Entries]
	) OR
	   NOT EXISTS (
		SELECT COUNT(*) FROM [dbo].[ProjXOrgR]
	)
		SELECT @ErrorMessage = 'You must execute usp_ClassifyAccounts_LoadTablesAndAttemptToMatch before continuing.'
	ELSE IF NOT EXISTS (
		SELECT [dbo].[udf_CheckIfAllIntermediateExpenseTablesHaveBeenLoaded]()
	)
		SELECT @ErrorMessage = 'You must execute usp_LoadFinancialData before continuing.'

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

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	---------------------------------------------------------
	-- Transfer expenses from intermediate tables to AD-419 Expense
	-- table section: 

	-- Load the non-204, non-20x, non-CE and non-Field Station Expenses:
	-- Load FIS Expenses:
	EXEC sp_Repopulate_AD419_20x_FIS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''FIS''

	-- Load PPS Expenses:
	EXEC sp_Repopulate_AD419_20x_PPS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''PPS''
	
	-- Load the 204 Expenses:
	-- Load 204 FIS Expenses:
	EXEC sp_Repopulate_AD419_20x_FIS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''204''

	-- Load 204 PPS Expenses:
	EXEC sp_Repopulate_AD419_20x_PPS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''204''

	-- Load the 20x Expenses:
	-- Load 20x FIS Expenses:
	EXEC sp_Repopulate_AD419_20x_FIS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''20x''

	-- Load 20x PPS Expenses:
	EXEC sp_Repopulate_AD419_20x_PPS_Expenses @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
			@TableName = ''AllExpenses'',
			@DataSource = ''20x''
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END