-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Checks if prerequsites have been met,
-- and loads Field Stations (22f) Expenses into Expenses and
-- Associates.
--
-- Prerequsites:
-- 1. Field Station Expense Import table count(*) > 1
-- 2. Project count(*) > 1
-- 3. ProjXOrgR count(*) > 1
--
-- Usage:
--
/*
	EXEC usp_LoadFieldStationExpensesIntoExpensesAndAssociate
		@FiscalYear = 2015, @IsDebug = 0
*/
--
-- Modifications:
--	20160914 by kjt: Added RAISEERROR to throw exceptions back to caller.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadFieldStationExpensesIntoExpensesAndAssociate] 
	@FiscalYear int = 2015, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(MAX) = ''
	
	DECLARE @FieldStationExpensesImportCount int = 0
	DECLARE @ProjectCount int = 0
	DECLARE @ProjectXOrgRCount int = 0
	
	SELECT @FieldStationExpensesImportCount = (
		SELECT COUNT(*) FROM FieldStationExpenseListImport
	)

	SELECT @ProjectCount = (
		SELECT COUNT(*) FROM Project
	)

	SELECT @ProjectXOrgRCount = (
		SELECT COUNT(*) FROM ProjXOrgR
	)

	DECLARE @ErrorMessage varchar(500) = ''
	IF @FieldStationExpensesImportCount = 0
		SELECT @ErrorMessage = 'Field Station Expenses must be imported before continuing.'
	ELSE IF @ProjectCount = 0
		SELECT @ErrorMessage = 'Projects must be imported before continuing.'
	ELSE IF @ProjectXOrgRCount = 0
		SELECT @ErrorMessage = 'EXECUTE usp_ClassifyAccounts_LoadTablesAndAttemptToMatch before continuing.'

	IF @ErrorMessage IS NOT NULL AND @ErrorMessage NOT LIKE ''
	BEGIN
		IF @IsDebug = 1
			PRINT '--' + @ErrorMessage + '
	'
		IF @IsDebug = 0
		BEGIN
			RAISERROR(@ErrorMessage, 16, 1)
			RETURN -1
		END
	END
	
	SELECT @TSQL = 	'
	DECLARE @return_value int
	EXEC	@return_value = [dbo].[sp_INSERT_22F_EXPENSES_INTO_EXPENSES]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END