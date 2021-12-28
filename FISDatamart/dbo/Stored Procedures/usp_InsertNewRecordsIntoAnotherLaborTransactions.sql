

-- =============================================
-- Author:		Ken Taylor
-- Create date: August 19, 2021
-- Description:	Inserts new records into the AnotherLaborTransactions table after all the inserts and updates
--		have been applied to the AnotherLaborTransactions_temp table.
-- Notes: Assumes source "temp" table is named <@TableName>_temp
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int, @IsDebug bit = 0

SET NOCOUNT ON;
EXEC	[dbo].[usp_InsertNewRecordsIntoAnotherLaborTransactions]
		@FiscalYear = 2021,
		@IsDebug = @IsDebug,
		@TableName = 'AnotherLaborTransactions',  -- Can change table for testing purposes
		@NumRecordsAdded = @return_value OUTPUT

IF @IsDebug = 0
		SELECT	'NumRecordsAdded (Output value from sproc): ' = @return_value
SET NOCOUNT OFF;

GO

*/
-- Modifications
-- 2021-08-20 by kjt: Commented out call to disable indexes as this took significantly longer to rebuild than
--		if they were left enabled.
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertNewRecordsIntoAnotherLaborTransactions] 
	@FiscalYear int = 2021, 
	@IsDebug bit = 0,
	@TableName varchar(250) = 'AnotherLaborTransactions',  -- Destination table name.  Assumes source temp table is named @TableName_temp.
	@NumRecordsAdded int OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET ANSI_NULLS ON

	SET QUOTED_IDENTIFIER ON

	--DECLARE @IsDebug bit = 1 -- Passed by param
	--DECLARE @FiscalYear int= 2021-- Passed by param
	--DECLARE @TableName varchar(250) = 'AnotherLaborTransactions'-- Passed by param
	DECLARE @OriginalTableName varchar(250) = @TableName
	SELECT @TableName += '_Temp'

	DECLARE @NewRecordsCount int = 0
	DECLARE @TSQL nvarchar(MAX) = ''

	IF @IsDebug = 1
		SELECT @TSQL = '
	DECLARE @NewRecordsCountOut int  --This only has to be added if we''re printing out the SQL statement ; otherwise it''s a dup.
'
	SELECT @TSQL += '
	SELECT @NewRecordsCountOut = (SELECT count(*) 
	FROM [dbo].[' + @TableName + '] t1
	WHERE NOT EXISTS (
		SELECT 1 
		FROM [dbo].[' + @OriginalTableName + '] t2
		WHERE t1.[LaborTransactionId] = t2.[LaborTransactionId] AND
			t1.ReportingYear = ' + CONVERT(char(4), @FiscalYear) + ' AND
			t1.ReportingYear = t2.ReportingYear 
		)
	)'

	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL + '
	IF @NewRecordsCountOut = 0 
		SELECT ''NewRecordsCountOut:'' = @NewRecordsCountOut
	ELSE
		SELECT ''NewRecordsCountOut to be added:'' = FORMAT(@NewRecordsCountOut, ''###,###,###'') 
'
	END
	ELSE
	BEGIN
		DECLARE @Params nvarchar(100) = N'@NewRecordsCountOut int output'
		EXEC sp_executesql @TSQL, @Params, @NewRecordsCountOut=@NewRecordsCount output 
		SELECT @NewRecordsCount AS NewRecordsCount
		SELECT 'NewRecordsCount from sp_executesql: ' + CONVERT(varchar(10),  @NewRecordsCount) AS [Message:] 

	END

	IF @NewRecordsCount > 0 OR @IsDebug = 1
	BEGIN
		SET NOCOUNT ON; 

		IF @IsDebug = 1
			PRINT  '
	IF @NewRecordsCountOut > 0
		BEGIN'

	DECLARE YearPeriodCursor CURSOR FOR
		SELECT * FROM [dbo].[udf_GetYearPeriodTableForFFY](2021) AS READONLY

	OPEN YearPeriodCursor
	DECLARE @Year int, @Period int
	FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
	WHILE @@FETCH_STATUS <> -1

	BEGIN
		SELECT @TSQL = '
			INSERT INTO [dbo].[' + @OriginalTableName + '](     
				   [LaborTransactionId]
				  ,[Chart]
				  ,[Account]
				  ,[SubAccount]
				  ,[Org]
				  ,[ObjConsol]
				  ,[Object]
				  ,[FinanceDocTypeCd]
				  ,[DosCd]
				  ,[EmployeeID]
				  ,[PPS_ID]
				  ,[EmployeeName]
				  ,[POSITION_NBR]
				  ,[EFFDT]
				  ,[TitleCd]
				  ,[RateTypeCd]
				  ,[Hours]
				  ,[Amount]
				  ,[Payrate]
				  ,[CalculatedFTE]
				  ,[PayPeriodEndDate]
				  ,[FringeBenefitSalaryCd]
				  ,[AnnualReportCode]
				  ,[ExcludedByARC]
				  ,[ExcludedByOrg]
				  ,[ExcludedByAccount]
				  ,[ExcludedByObjConsol]
				  ,[ExcludedByDOS]
				  ,[IncludeInFTECalc]
				  ,[ReportingYear]
				  ,[School]
				  ,[OrgId]
				  ,[PAID_PERCENT]
				  ,[ERN_DERIVED_PERCENT]
				  ,[IsAES]
				  ,[LastUpdateDate]
				  ,[Year]
				  ,[Period]
				  ,[EMP_RCD]
				  ,[EFFSEQ]
			)
			SELECT  [LaborTransactionId]
				  ,[Chart]
				  ,[Account]
				  ,[SubAccount]
				  ,[Org]
				  ,[ObjConsol]
				  ,[Object]
				  ,[FinanceDocTypeCd]
				  ,[DosCd]
				  ,[EmployeeID]
				  ,[PPS_ID]
				  ,[EmployeeName]
				  ,[POSITION_NBR]
				  ,[EFFDT]
				  ,[TitleCd]
				  ,[RateTypeCd]
				  ,[Hours]
				  ,[Amount]
				  ,[Payrate]
				  ,[CalculatedFTE]
				  ,[PayPeriodEndDate]
				  ,[FringeBenefitSalaryCd]
				  ,[AnnualReportCode]
				  ,[ExcludedByARC]
				  ,[ExcludedByOrg]
				  ,[ExcludedByAccount]
				  ,[ExcludedByObjConsol]
				  ,[ExcludedByDOS]
				  ,[IncludeInFTECalc]
				  ,[ReportingYear]
				  ,[School]
				  ,[OrgId]
				  ,[PAID_PERCENT]
				  ,[ERN_DERIVED_PERCENT]
				  ,[IsAES]
				  ,[LastUpdateDate]
				  ,[Year]
				  ,[Period]
				  ,[EMP_RCD]
				  ,[EFFSEQ]
				FROM [dbo].[' + @TableName + '] t1
				WHERE NOT EXISTS (
					SELECT 1 
					FROM [dbo].[' + @OriginalTableName + '] t2
					WHERE t1.[LaborTransactionId] = t2.[LaborTransactionId] AND
						t1.ReportingYear = t2.ReportingYear
				) AND Year = ' + CONVERT(char(4), @Year) + ' AND Period = ' + CONVERT(varchar(2), @Period) + '
'
		IF @IsDebug = 1  
		BEGIN
			PRINT @TSQL
		END
		ELSE 
			EXEC(@TSQL)

		FETCH NEXT FROM YearPeriodCursor INTO @Year, @Period
	END --WHILE @@FETCH_STATUS <> -1

	CLOSE YearPeriodCursor
	DEALLOCATE YearPeriodCursor 
	
	SELECT @TSQL = '
			DECLARE @NumRecordsAdded int
'
	IF @IsDebug = 1
		SELECT @TSQL +=  '
			SELECT @NumRecordsAdded = @NewRecordsCountOut
'
	ELSE --@IsDebug != 1
		BEGIN
			SELECT @NumRecordsAdded =  @NewRecordsCount -- This sets the return value. apparently it can't easily be done
														-- using dynamic SQL.
			-- However, we also need to set it for the TSQL mesage (below)
			SELECT @TSQL = '
			DECLARE @NumRecordsAdded int
			SELECT @NumRecordsAdded = ' + CONVERT(varchar(10), @NewRecordsCount)
		END --Else @IsDebug != 1

		select @TSQL += '
			SELECT ''Completed adding '' + FORMAT(@NumRecordsAdded, ''###,###,###'') + '' new records for FFY ' + CONVERT(char(4), @FiscalYear )+ '.'' AS [Message:]

			-- 2021-07-23 by kjt: Re-enable/Rebuild indexes:
			EXEC usp_RebuildAllTableIndexes @TableName = [' + @OriginalTableName + ']
		
			--DROP TABLE [dbo].[' + @TableName + ']
'
		IF @IsDebug = 1
		BEGIN
			-- We add this extra else because we want to be able to re-run the generated SQL 
			-- when records have been loaded.
			SELECT @TSQL += '
		END
	ELSE
		BEGIN
			SET NOCOUNT ON; 

			SELECT ''There were no new records to be added for FFY ' + CONVERT(char(4), @FiscalYear )+ '.'' AS [Message:]

			--DROP TABLE [dbo].[' + @TableName + ']

			SET NOCOUNT OFF; 
		END
'
		END --@IsDebug = 1

	END	--IF @NewRecordsCount > 0
	ELSE 
	BEGIN
		SELECT @TSQL = '
		SET NOCOUNT ON; 
		SELECT ''There were no new records to be added for FFY ' + CONVERT(char(4), @FiscalYear )+ '.'' AS [Message:]

			--DROP TABLE [dbo].[' + @TableName + ']

			SET NOCOUNT OFF; 
'
		SELECT @NumRecordsAdded = @NewRecordsCount

	END --ELSE @NewRecordsCount = 0

	IF @IsDebug = 1 
		BEGIN
			SET NOCOUNT ON; 
			PRINT @TSQL
			SET NOCOUNT OFF;
		END
	ELSE 
		BEGIN
			EXEC(@TSQL)
		END
END -- sproc