
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

SET NOCOUNT ON

DECLARE	@return_value int,
		@NeedsReload bit

EXEC	@return_value = [dbo].[usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired]
		@FiscalYear = 2021,
		@IsDebug = 0,
		@NeedsReload = @NeedsReload OUTPUT


SELECT	@NeedsReload as N'@NeedsReload' -- If NULL then the records are not yet present in UCP. 

SELECT	'Return Value' = @return_value

GO

-- Results if does not need reloading:
-- Output:
@NeedsReload
0
-- Messages:
Current AD-419 Reporting Year: 2012-2013 -- This message only shown if @IsDebug = 1
Starting Fiscal Year (2012) matches Starting Pay Period Fiscal Year (2012) AND 
Ending Fiscal Year (2013) matches Ending Pay Period Fiscal Year (2013); therefore, BYPASSING reloading LaborTransactions table
for 2012-2013 AD-419 Reporting Year.
--
-- Results if does need reloading:
-- Output:
@NeedsReload
1
-- Messages:
Current AD-419 Reporting Year: 2012-2013 -- This message only shown if @IsDebug = 1
Starting Fiscal Year (2012) does NOT match Starting Pay Period Fiscal Year (2011) OR 
Ending Fiscal Year (2013 does NOT match Ending Pay Period Fiscal Year (2012); therefore, reloading LaborTransactions table
for 2012-2013 AD-419 Reporting Year.

-- Results if not all source data is present and can't continue as records for final period are not yet present.
@NeedsReload
NULL
-- Messages:
Current AD-419 Reporting Year: 2012-2013 -- This message only shown if @IsDebug = 1
Msg 50000, Level 16, State 1, Procedure dbo.usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired, Line 107 [Batch Start Line 22]
Unable to proceed with this step: All the records for the Reporting Year are not yet present. Try again after the close of the fiscal period 3 (September).

NOTE: 

*/
--
-- Modifications:
--	2016-10-31 by kjt: Revised to use the new "ReportingYear" column instead as the [PayPeriodEndDate] was giving
--	false negatives due to retroactive and future payments affecting the end date.
--	2021-09-03 by kjt: Revised to use with FISDataMart.dbo.AnotherLaborTransactions table,
--		which is presently located on caes-elzar.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired]
(
	@FiscalYear int = 2015, --The ending year of the current AD-419 Reporting Year
	@IsDebug bit = 1, --Set to 1 to print debug messages
	@NeedsReload bit OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON 
--DECLARE @FiscalYear int = 2013, @IsDebug bit = 1
DECLARE @MinAmountFinalPeriodRecordCount int = 300000
DECLARE @TSQL varchar(MAX) = ''
DECLARE @return_value int

DECLARE @FinalPeriodRecordCountPresent int = ISNULL(
(
	SELECT Count(*) 
	FROM [FISDataMart].[dbo].[AnotherLaborTransactions]
	WHERE ReportingYear = @FiscalYear AND
		Period = 3
),0)

	DECLARE @NumUcpLLRecords int 
	EXEC [dbo].[udf_GetLaborRecordCountForPeriodThree]
		@FiscalYear = @FiscalYear,
		@IsDebug = @IsDebug,
		@NumRecs = @NumUcpLLRecords OUTPUT

	IF @IsDebug = 1
	BEGIN
		SELECT 'NumUcpLLRecords' = @NumUcpLLRecords
		PRINT 'AD-419 Reporting Year provided: ' + CONVERT(varchar(4), @FiscalYear - 1) + '-' + CONVERT(varchar(4), @FiscalYear)
	END

IF @NumUcpLLRecords > @MinAmountFinalPeriodRecordCount  
	SELECT @MinAmountFinalPeriodRecordCount = @NumUcpLLRecords  -- Set the @MinAmountFinalPeriodRecordCount to the actual number
																--	of records present in the UCP labor tables.
IF @NumUcpLLRecords = 0 -- Maybe skip reload for now?  Or exit the process with an error message?
	BEGIN
	-- The final period records are not yet present, meaning the FFY hasn't closed yet, and we'll should skip the loading for now
		DECLARE @ErrorMessage varchar(250) = 'Unable to proceed with this step: All the records for the Reporting Year are not yet present. Try again after the close of the fiscal period 3 (September).'
		RAISERROR(@ErrorMessage, 16, 1)
		RETURN -1
	END

IF @FinalPeriodRecordCountPresent < @MinAmountFinalPeriodRecordCount --(300,000) 
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Record count for final period (03) of Reporting year ' + CONVERT(varchar(4), @FiscalYear) + ' present in AnotherLaborTransactions ' + 
			CONVERT(varchar(10), @FinalPeriodRecordCountPresent) + ' is less than minimum ' + CONVERT(varchar(10),@MinAmountFinalPeriodRecordCount) + 
			' expected; therefore, reloading AnotherLaborTransactions table is necessary
for ' + CONVERT(varchar(4), @FiscalYear - 1) + '-' + CONVERT(varchar(4), @FiscalYear) + ' AD-419 Reporting Year.
'
		SELECT @NeedsReload = 1;
	END
ELSE
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Record count ' + CONVERT(varchar(10), @FinalPeriodRecordCountPresent) + ' present in AnotherLaborTransactions meets or exceeds ' + 
			CONVERT(varchar(10), @MinAmountFinalPeriodRecordCount) + '; therefore, BYPASSING reloading AnotherLaborTransactions table
for ' + CONVERT(varchar(4), @FiscalYear - 1) + '-' + CONVERT(varchar(4), @FiscalYear) + ' AD-419 Reporting Year.
'

		SELECT @NeedsReload = 0;
	END
END