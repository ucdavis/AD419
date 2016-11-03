﻿-- =============================================
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
		@FiscalYear = 2016,
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
--	2016-10-31 by kjt: Revised to use the new "ReportingYear" column instead as the [PayPeriodEndDate] was giving
--	false negatives due to retroactive and future payments affecting the end date.
-- =============================================
CREATE PROCEDURE [dbo].[usp_CheckIfAnotherLaborTransactionsTableReloadIsRequired]
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

DECLARE @ReportingYear int = ISNULL((SELECT DISTINCT [ReportingYear] FROM [AD419].[dbo].[AnotherLaborTransactions]), 0)

IF @IsDebug = 1
	PRINT 'Current AD-419 Reporting Year: ' + CONVERT(varchar(4), @ReportingYear - 1) + '-' + CONVERT(varchar(4), @ReportingYear)

IF @ReportingYear <> @FiscalYear 
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Reporting year ' + CONVERT(varchar(4), @ReportingYear) + ' present in AnotherLaborTransactions does NOT equal ' + 
			CONVERT(varchar(4), @FiscalYear) + '; therefore, reloading AnotherLaborTransactions table is necessary
for ' + CONVERT(varchar(4), @ReportingYear - 1) + '-' + CONVERT(varchar(4), @ReportingYear) + ' AD-419 Reporting Year.
'
		SELECT @NeedsReload = 1;
	END
ELSE
	BEGIN
		--IF @IsDebug = 1
			PRINT 'Reporting year ' + CONVERT(varchar(4), @ReportingYear) + ' present in AnotherLaborTransactions matches ' + 
			CONVERT(varchar(4), @FiscalYear) + '; therefore, BYPASSING reloading AnotherLaborTransactions table
for ' + CONVERT(varchar(4), @ReportingYear - 1) + '-' + CONVERT(varchar(4), @ReportingYear) + ' AD-419 Reporting Year.
'

		SELECT @NeedsReload = 0;
	END
END