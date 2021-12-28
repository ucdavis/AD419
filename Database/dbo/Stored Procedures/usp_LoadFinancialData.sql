
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 19, 2016
-- Description:	Loads all of the financial data tables
-- necessary to build master list of expenses to
-- report against.
--
-- Usage:
/*
	EXEC usp_LoadFinancialData @FiscalYear = 2016, @IsDebug = 1
*/
--
-- Modifications:
--	20160820 by kjt: Added exit statements if prerequisites were not met.
--	20160920 by kjt: Added RAISE ERROR statements so that user-generated exceptions will be returned to caller.
--	20161019 by kjt: Fixed hard-coded fiscal years that were intended to use passed parameter.
--		Also added filtering out of any account in ARCCodeAccountExclusionsV
--	20170118 by kjt: Removed statements that were previously commented out.
--	20171025 by kjt: Added @FiscalYear parameters where required.
--	20191011 by kjt: Added @FiscalYear parameter to Load PPSExpensesFor204Projects.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadFinancialData] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Check that the previous stored procedure has been run,  
	-- that all 204 and 20x matches have been made, and 
	-- that all expiring 20x projects have been remapped:
	DECLARE @NumEntries int = 0
	DECLARE @Unmatched int = 0
	DECLARE @NonRemappedExpiredProjects int = 0

	SELECT @NumEntries = (
		SELECT COUNT(*) 
		FROM [dbo].[FFY_SFN_Entries])

	SELECT @Unmatched = ( 
		Select count(*) 
		from [dbo].[FFY_SFN_Entries] t1 
		WHERE (
			((t1.Chart + t1.Account) NOT IN (
				SELECT
					Chart + Account AS Expr1 
				FROM
					dbo.ARCCodeAccountExclusionsV)) AND
			(t1.SFN NOT LIKE '204') OR ((t1.Chart + t1.Account) NOT IN (
				SELECT
					Chart + Account AS Expr1 
				FROM
					dbo.ARCCodeAccountExclusionsV AS ARCCodeAccountExclusionsV_1)) AND
			(t1.SFN LIKE '204') AND
			(t1.IsExpired = 0 OR t1.IsExpired IS NULL)
			) AND 
			AccessionNumber IS NULL
	) 

	SELECT @NonRemappedExpiredProjects = (
		SELECT COUNT(*) FROM (
			SELECT AccessionNumber FROM [dbo].[udf_GetExpired20xProjects] (@FiscalYear)
			EXCEPT 
			SELECT FromAccession AccessionNumber FROM ExpiredProjectCrossReference
		) t1
	)

	DECLARE @ErrorMessage varchar(1024) = ''
	IF @NumEntries = 0
		SELECT @ErrorMessage = 'You must first run usp_ClassifyAccounts_LoadTablesAndAttemptToMatch before continuing.'
	ELSE IF @Unmatched > 0
		SELECT @ErrorMessage = 'You must match ' + CONVERT(varchar(5), @Unmatched)+ ' unmatched 204 or 20x Projects before continuing.'
	ELSE IF @NonRemappedExpiredProjects > 0
		SELECT @ErrorMessage = 'You must remap ' + CONVERT(varchar(5), @NonRemappedExpiredProjects)+ ' expired 20x Projects before continuing.'

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
	-- Load intermediate expense and labor related tables section:

	-- Load MissingExpensesFor204Projects:
	EXEC [dbo].[usp_LoadMissing204AccountExpenses]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	-- Load PPSExpensesFor204Projects:
	EXEC [dbo].[usp_LoadPPSExpensesFor204Projects]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	-- Load FISExpensesFor204Projects:
	EXEC [dbo].[usp_LoadFISExpensesFor204Projects]
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	-- Load PPSExpensesForNon204Projects:
	EXEC [dbo].[usp_LoadPPSExpensesForNon204Projects]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	-- Load FISExpensesForNon204Projects:
	EXEC [dbo].[usp_LoadFISExpensesForNon204Projects]
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END