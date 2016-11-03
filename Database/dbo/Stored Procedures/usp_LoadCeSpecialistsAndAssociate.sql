-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Check if OK, and load CE Specialists and Associate.
--
-- Prerequsites:
-- 1. CESListImport loaded (count(*) > 1
-- 2. Project count(*) > 1
-- 3. ProjXOrgR count(*) > 1
--
-- Usage
/*
	EXEC usp_LoadCeSpecialistsAndAssociate
		@FiscalYear = 2015, @IsDebug = 0
*/
--
-- Modifications
--	20160914 by kjt: Added RAISE ERROR logic to return user generated exceptions back to caller.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadCeSpecialistsAndAssociate] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2015, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @CesListImportCount int = 0
	DECLARE @ProjectCount int = 0
	DECLARE @ProjectXOrgRCount int = 0

	SELECT @CesListImportCount = (
		SELECT COUNT(*) FROM CesListImport
	)

	SELECT @ProjectCount = (
		SELECT COUNT(*) FROM Project
	)

	SELECT @ProjectXOrgRCount = (
		SELECT COUNT(*) FROM ProjXOrgR
	)

	DECLARE @ErrorMessage varchar(200) = ''
	IF @CesListImportCount = 0
		SELECT @ErrorMessage = 'CES Expenses must be imported before continuing.'
	ELSE IF @ProjectCount = 0
		SELECT @ErrorMessage = 'Projects must be imported before continuing.'
	ELSE IF @ProjectXOrgRCount = 0
		SELECT @ErrorMessage = 'usp_ClassifyAccounts_LoadTablesAndAttemptToMatch must be executed before continuing.'
	
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
	DECLARE	@return_value int

	-- Populate the tables that the Admin tab of AD419 uses by calling:
	EXEC	@return_value = [dbo].[sp_INSERT_CE_EXPENSES_INTO_CESXProjects]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@TableName = N''CES_List_V'',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value

	-- Lastly, transfer the CE values to the Expenses and Associations tables using the following

	EXEC	@return_value = [dbo].[sp_Repopulate_AD419_CE]
			@FiscalYear = 9999,
			@SFN = N''220'',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END