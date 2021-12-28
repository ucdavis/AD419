-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Check if OK, and associate 241 employees.
--
-- Prerequisites:
-- All expenses must be loaded and all PI_Matches must be made or
-- set to IsProrated.
--
-- Usage:
--
/*
	EXEC usp_AutoAssociate241Employees
		@FiscalYear = 2016, @IsDebug = 0
*/
--
-- Modifications:
--	20160914 by kjt: Removed check for UnmatchedPiNames and revised to call usp_InsertAssociationsFor241Expenses.
-- =============================================
CREATE PROCEDURE [dbo].[usp_AutoAssociate241Employees] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

		DECLARE @FISCount int = 0, @PPSCount int = 0, @204Count int = 0, @20xCount int = 0, @CESCount int = 0,
	@FieldStationExpenseCount int = 0, @ProjectCount int = 0, @ProjectXOrgRCount int = 0, @UnmatchedPiNames int = 0

	SELECT @FISCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'FIS'
		)

	SELECT @PPSCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'PPS'
		)

	SELECT @204Count = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '204'
		)

	SELECT @20xCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '20x'
		)

	SELECT @CESCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'CES'
		)

	SELECT @FieldStationExpenseCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '22f'
		)

	SELECT @ProjectCount = (
		SELECT COUNT(*) FROM Project
	)

	SELECT @ProjectXOrgRCount = (
		SELECT COUNT(*) FROM ProjXOrgR
	)

	--SELECT @UnmatchedPiNames = (
	--	 SELECT count(*) from PI_MATCH WHERE PI_MATCH IS NULL AND (IsProrated = 0 OR IsProrated IS NULL)
	--)

	DECLARE @ErrorMessage varchar(200) = ''
	IF @FISCount = 0 OR @PPSCount = 0 OR @204Count = 0 OR @20xCount = 0
		SELECT @ErrorMessage = 'usp_LoadFinancialData must be executed before continuing.'
	ELSE IF @CESCount = 0
		SELECT @ErrorMessage = 'CES Expenses must be loaded into expenses before continuing.'
	ELSE IF @FieldStationExpenseCount = 0
		SELECT @ErrorMessage = 'Field Station Expenses must be loaded into expenses before continuing.'
	ELSE IF @ProjectCount = 0
		SELECT @ErrorMessage = 'Projects must be imported before continuing.'
	ELSE IF @ProjectXOrgRCount = 0
		SELECT @ErrorMessage = 'usp_ClassifyAccounts_LoadTablesAndAttemptToMatch must be executed before continuing.'
	--ELSE IF @UnmatchedPiNames > 0
	--	SELECT @ErrorMessage = 'You must match PI Names or set unmatched name''s "IsProrated" to true before continuing.'
	
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
	-- Auto-Associate 241 Employees:
	DECLARE	@return_value int

	EXEC @return_value = [dbo].[usp_InsertAssociationsFor241Expenses] @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
			
	SELECT	''Return Value'' = @return_value
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END