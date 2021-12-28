
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 18, 2016
-- Description:	Executes all the stored procedures associated
-- with the starting the process for a new reporting period.
-- Usage:
/*
	EXEC usp_BeginProcessingForNewReportingPeriod @FiscalYear = 2018, @IsDebug = 1
*/
--
-- Modifications:
--	20160906 by kjt: Added logic to clear process status and process category tables.
--	20160915 by kjt: Split out download ARC codes piece so they could be reviewed prior
--	  to downloading expenses by ARC, etc.
--	20160919 by kjt: Uncommented loading of the FFY_ExpensesByARC and UFY_FFY_FIS_Expenses,
--	  which I believe was commented out by mistake. 
--	20160922 by kjt: Commented out logic for setting status, as I believe this was clearing out
--	  the previously set statuses.
--	20161004 by kjt: Fixed name of usp_UpdateAnotherLaborTransactionsMissingEmployeeNames.
--	20161018 by kjt: Revised ARC Code/Account copying logic to only copy over missing entries as it 
--	  was attempting to copy over more items that it should have.
--  20161020 by kjt: Added DISTINCT to ARCCodeAccountExclusion copying segment.
--	20170118 by kjt: Removed commented out statement for easier readability.
--	20171012 by kjt: Added conditional call of usp_Load_UFY_FFY_FIS_Expenses if Fiscal Year is different 
--		than current reporting year.
--	20181029 by kjt: Fixed issue with ARC/Account exclusions copying over more that 1 row 
--		from the previous reporting year.
--		Added sorting to ARC/Account exclusions. 
--	20201019 by kjt: Removed call to usp_UpdateAnotherLaborTransactionsMissingEmployeeNames, as
--		all of the employee names were populated in the load AnotherLaborTransaction sproc.
--
CREATE PROCEDURE [dbo].[usp_BeginProcessingForNewReportingPeriod] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2018,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	--Truncate any tables containing data from prior report period that
	-- will not be automated upon reload OR that will cause last year''s
	-- data to show up in the AD-419 application:
	EXEC [dbo].[usp_TruncateTablesForReload] @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', 
		@TruncateImportTables = 1,
		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '

	-- Copy ARCCodeAccountExclusions from prior year:
	INSERT INTO [dbo].[ArcCodeAccountExclusions] 
	SELECT DISTINCT ' + CONVERT(varchar(4), @FiscalYear) + ' [Year]
      ,t1.[Chart]
      ,t1.[Account]
      ,t1.[AnnualReportCode]
      ,t1.[Comments]
      ,t1.[Is204]
      ,t1.[AwardNumber]
      ,t1.[ProjectNumber] FROM [dbo].[ArcCodeAccountExclusions] t1
	INNER JOIN (
	SELECT ' + CONVERT(varchar(4), @FiscalYear) + ' [Year]
		,[Chart]
        ,[Account]
        ,[AnnualReportCode]
    FROM [dbo].[ArcCodeAccountExclusions]
	WHERE Year = ' + CONVERT(varchar(4), @FiscalYear -1) + ' 
	EXCEPT
	SELECT [Year]
		,[Chart]
        ,[Account]
        ,[AnnualReportCode] 
	FROM [dbo].[ArcCodeAccountExclusions]
	WHERE Year = ' + CONVERT(varchar(4), @FiscalYear) + ') t2 
	ON t1.Year = ' + CONVERT(varchar(4), @FiscalYear - 1 -- (The previous year we''re copying over from)
	) + ' AND t1.Chart = t2.Chart AND t1.Account = t2.Account AND t1.AnnualReportCode = t2.AnnualReportCode
	ORDER BY t1.[Chart], t1.[Account], t1.[AnnualReportCode]

	-- Truncate and reload FFY_ExpensesByARC:
	TRUNCATE TABLE FFY_ExpensesByARC
	INSERT INTO FFY_ExpensesByARC
	SELECT * FROM udf_GetDirectAndIndirectFFYExpensesByARCandAccount ('+ CONVERT(varchar(4), @FiscalYear) +')
	-----------------------------------------------------------------------------------------------------------
	DECLARE @NeedsReload bit
	DECLARE @ReportingYear int
	
	SELECT @ReportingYear = (	
		SELECT DISTINCT FiscalYear 
		FROM [dbo].[UFY_FFY_FIS_Expenses]
	)

	IF @ReportingYear IS NULL OR @ReportingYear != ' + CONVERT(varchar(4), @FiscalYear) + '
	BEGIN
		-- Load UFY_FFY_FIS_Expenses
		EXEC [dbo].[usp_Load_UFY_FFY_FIS_Expenses] @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', 
			@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
	END

	-- Reload AnotherLaborTransactions if necessary:
	--DECLARE @NeedsReload bit
	DECLARE @return_value int

	EXEC @return_value = [dbo].[usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired]
		@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) +',
		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + ',
		@NeedsReload = @NeedsReload OUTPUT
	SELECT	@NeedsReload as N''@NeedsReload''

	IF @NeedsReload = 1
		BEGIN
			EXEC @return_value = usp_LoadAnotherLaborTransactions 
				@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
				@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
			SELECT	''Return Value'' = @return_value

		-- 20201019 by kjt: Commented out this step as all employee names
		--		were populated in the previous step.
		--	EXEC @return_value = usp_UpdateAnotherLaborTransactionsMissingEmployeeNames 
		--		@IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
		--SELECT	''Return Value'' = @return_value
	END
'

	IF @IsDebug = 1
		PRINT @TSQL	
	ELSE
		EXEC(@TSQL)

END