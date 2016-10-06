-- =============================================
-- Author:		Ken Taylor
-- Create date: 2016-08-20
-- Description:	Returns true (1) or false (0) depending on whether or not the starting and ending
-- fiscal years match the min and max payroll period end dates.
--
-- This check is made because the AnotherLaborTransactions table load process takes some time and only needs to be done once
-- at the beginning of the AD-419 load process. 
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int,
		@NeedsReload bit

EXEC	@return_value = [dbo].[usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired]
		@FiscalYear = 2015,
		@IsDebug = 1,
		@NeedsReload = @NeedsReload OUTPUT

SELECT	@NeedsReload as N'@NeedsReload'

SELECT	'Return Value' = @return_value

GO

-- Results if does not need reloading:
-- Output:
@NeedsReload
0
-- Messages:
Current AD-419 Reporting Year: 2012-2013
Starting Fiscal Year (2012) matches Starting Pay Period Fiscal Year (2012) AND 
Ending Fiscal Year (2013) matches Ending Pay Period Fiscal Year (2013); therefore, BYPASSING reloading LaborTransactions table
for 2012-2013 AD-419 Reporting Year.
--
-- Results if does need reloading:
-- Output:
@NeedsReload
1
-- Messages:
Current AD-419 Reporting Year: 2012-2013
Starting Fiscal Year (2012) does NOT match Starting Pay Period Fiscal Year (2011) OR 
Ending Fiscal Year (2013 does NOT match Ending Pay Period Fiscal Year (2012); therefore, reloading LaborTransactions table
for 2012-2013 AD-419 Reporting Year.
*/
--
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired
(
	@FiscalYear int = 2015, --The ending year of the current AD-419 Reporting Year
	@IsDebug bit = 1, --Set to 1 to print debug messages
	@NeedsReload bit OUTPUT
)
AS
BEGIN

--DECLARE @FiscalYear int = 2013, @IsDebug bit = 1

DECLARE @TSQL varchar(MAX) = ''
DECLARE @return_value int
DECLARE @StartingFiscalYear int = @FiscalYear -1
DECLARE @EndingFiscalYear int = @FiscalYear
DECLARE @StartingPayPeriodYear int = ISNULL((SELECT YEAR(MIN([PayPeriodEndDate])) FROM [AD419].[dbo].[AnotherLaborTransactions]), 0)
DECLARE @EndingPayPeriodYear int = ISNULL((SELECT YEAR(MAX([PayPeriodEndDate])) FROM [AD419].[dbo].[AnotherLaborTransactions]), 0)

IF @IsDebug = 1
	PRINT 'Current AD-419 Reporting Year: ' + CONVERT(varchar(4), @StartingFiscalYear) + '-' + CONVERT(varchar(4), @EndingFiscalYear)

IF @StartingFiscalYear < @StartingPayPeriodYear OR @EndingFiscalYear > @EndingPayPeriodYear
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Starting Fiscal Year (' + CONVERT(varchar(4), @StartingFiscalYear) + ') less than the Starting Pay Period Fiscal Year (' + CONVERT(varchar(4), @StartingPayPeriodYear) + ') OR 
Ending Fiscal Year (' + CONVERT(varchar(4), @EndingFiscalYear) + ' greater than the Ending Pay Period Fiscal Year (' + CONVERT(varchar(4), @EndingPayPeriodYear) + '); therefore, reloading AnotherLaborTransactions table
for ' + CONVERT(varchar(4), @StartingFiscalYear) + '-' + CONVERT(varchar(4), @EndingFiscalYear) + ' AD-419 Reporting Year.

'

--		SELECT @TSQL = 'EXEC @return_value = dbo.usp_LoadAnotherLaborTransactions @FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ', @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
--SELECT	''Return Value'' = @return_value

--'

--		IF @IsDebug = 1
--			PRINT @TSQL
--		ELSE 
--			BEGIN
--				EXEC @return_value = sp_executesql @TSQL
--				PRINT	'Return Value = ' + CONVERT(varchar(5), @return_value)
--			END

--		SELECT @TSQL = 'EXEC @return_value = usp_UpdateAnotherLaborTransactionsMissingEmployeeNames @IsDebug = ' + CONVERT(varchar(1), @IsDebug) + '
--SELECT	''Return Value'' = @return_value

--'
--		IF @IsDebug = 1
--			PRINT @TSQL
--		ELSE 
--			BEGIN
--				EXEC @return_value = sp_executesql @TSQL
--				PRINT	'Return Value = ' + CONVERT(varchar(5), @return_value)
--			END
		SELECT @NeedsReload = 1;
	END
ELSE
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Starting Fiscal Year (' + CONVERT(varchar(4), @StartingFiscalYear) + ') is greater than or equal to the Starting Pay Period Fiscal Year (' + CONVERT(varchar(4), @StartingPayPeriodYear) + ') AND 
Ending Fiscal Year (' + CONVERT(varchar(4), @EndingFiscalYear) + ') is less than or equal to the Ending Pay Period Fiscal Year (' + CONVERT(varchar(4), @EndingPayPeriodYear) + '); therefore, BYPASSING reloading AnootherLaborTransactions table
for ' + CONVERT(varchar(4), @StartingFiscalYear) + '-' + CONVERT(varchar(4), @EndingFiscalYear) + ' AD-419 Reporting Year.'

		SELECT @NeedsReload = 0;
	END
END