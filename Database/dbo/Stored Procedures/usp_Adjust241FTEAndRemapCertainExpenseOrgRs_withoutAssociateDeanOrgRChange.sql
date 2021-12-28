-- =============================================
-- Author:		Ken Taylor
-- Create date: September 21, 2017
-- Description:	Check that all expenses with title codes
-- have been loaded, and update FTE_SFN to 241 for various
-- title codes that should have been classified as scientists
-- because they are a PI of Record.  Also remap certain expenses
-- OrgRs.  (See code for additional details.)
--
-- Prerequisites:
-- All expenses have been loaded for FIS, PPS, 204 and 20x, and CE 
-- Specialists prior to 241 FTE_SFN adjustment
-- Project and ProjXOrgR has been loaded prior to loading PI_Match. 
--
-- Usage
/*
	EXEC usp_Adjust241FTEAndRemapCertainExpenseOrgRs
		@FiscalYear = 2016, @IsDebug = 0
*/
--
-- Modifications
--	20170921 by kjt: Replaces usp_Adjust241FTEAndPopulatePiMatch.
--	20170927 by kjt: Commented out call to [dbo].[usp_RemapAssociateDeansExpenseDepartmentsToADNO]
--		for testing and comparison purposes.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Adjust241FTEAndRemapCertainExpenseOrgRs_withoutAssociateDeanOrgRChange] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @FISCount int = 0, @PPSCount int = 0, @204Count int = 0, @20xCount int = 0, @CESCount int = 0,
	@FieldStationExpenseCount int = 0, @ProjectCount int = 0, @ProjectXOrgRCount int = 0

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

	DECLARE @ErrorMessage varchar(200) = ''
	IF @FISCount = 0 OR @PPSCount = 0 OR @204Count = 0 OR @20xCount = 0
		SELECT @ErrorMessage = 'usp_LoadFinancialData must be executed before continuing.'
	ELSE IF @CESCount = 0
		SELECT @ErrorMessage = 'CES Expenses must be loaded into expenses before continuing.'
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
	-- Adjust the FTE_SFN for 241 Employees by calling:
	DECLARE	@return_value int

	EXEC @return_value = [dbo].[sp_Adjust241FTE]
			
	SELECT	''Return Value'' = @return_value
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-------------------------------------------------------
	-- Remapping of ADNO employee expenses to AIND section:
	-- This is done here so we can make later make a match on any 241 employee expense,
	-- and also use the AD-419 Reporting Module to associate any employee expenses for 
	-- which there were no employee(s) associated.
	SELECT @TSQL = '
	-- Remap ADNO AGARGAA employee expenses to AIND:
	DECLARE	@return_value2 int 
	
	EXEC	@return_value2 = [dbo].[sp_Associate_AD419_IND_with_AIND] @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
			
	SELECT	''Return Value'' = @return_value2
	'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

	-------------------------------------------------------
	-- Change OrgR for Associate Deans section:

	SELECT @TSQL = '
	-- Change the OrgR for Associate Deans to ADNO to allow automatic proration across all 
	-- College''s projects and to hide corresponding expenses for AD-419 reporting module:
	DECLARE	@return_value3 int '
	SELECT @TSQL += '
	EXEC	@return_value3 = [dbo].[usp_RemapAssociateDeansExpenseDepartmentsToADNO] @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
			
	SELECT	''Return Value'' = @return_value3
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END