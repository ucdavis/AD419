-- =============================================
-- Author:		Ken Taylor
-- Create date: April 6, 2011
-- Description:	Call a table's load procedure to load a partitioned "load" table 
-- and then swap the entire partition to the main table.
-- Modifications:
-- 20110414 by kjt:
--	Modified to call usp_LoadNamedTransLogTable.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadTableUsingSwapPartitions] 
	@FirstDateString varchar(16) = null,
		--earliest date to download  
		--optional, defaults to highest date in table
	@LastDateString varchar(16) = null,
		-- latest date to download 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- This parameter is just a placeholder so that it can be called
		-- using usp_Download_TableRecordsForFiscalYear.
	@TableName varchar(255) = 'TransLog', --Can be passed another table name, i.e. #TransLog, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute it. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- SET NOCOUNT ON;
		-- Minimal date logic used to build the where clause,
	-- because the assumption is that is was derermined by the 
	-- calling procedure.
	
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	
	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @WhereClause varchar(MAX) = ''
	
	DECLARE @NumFiscalYearsToDownload smallint = 1
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'TransLog' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 0 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	--IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
-------------------------------------------------------------------------------------	
	DECLARE @DestinationTableName varchar(50) = @TableName 
	DECLARE @LoadTableName varchar(50) = @DestinationTableName + 'Load'

	DECLARE @EmptyTableName varchar(50) = @DestinationTableName + 'Empty'
	DECLARE @PartnNum smallint
	
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
	PRINT '--Start time for usp_LoadTableUsingSwapPartitions: ' +  + CONVERT(varchar(20),@StartTime, 114)
	
	SELECT @TSQL = '
	TRUNCATE TABLE ' + @LoadTableName + '

	EXEC	[dbo].[usp_LoadNamedTransLogTable]
			@FirstDateString = ''' + @FirstDateString + ''',
			@LastDateString = ''' + @LastDateString + ''',
			@GetUpdatesOnly = 0,
			@TableName = ''' + @LoadTableName + ''',
			@IsDebug = ' + CONVERT (char(1), @IsDebug) + '
	'
	
	SELECT @PartnNum = (dbo.udf_GetPartitionForFiscalYear(@BeginningFiscalYear))
	PRINT '--' + Convert(char(4), @BeginningFiscalYear) + '''s partition number is ' + CONVERT(char(1),@PartnNum)
	
		-- Note that the receiving partition MUST be empty.
		-- Therefore, 
		-- Swap the TransLog's old years partition's record set with an empty one from TransLogEmpty
		SELECT @TSQL += '
	ALTER TABLE ' + @DestinationTableName + 
'
	SWITCH PARTITION ' + CONVERT(char(1),@PartnNum) + ' TO ' + @EmptyTableName + ' PARTITION ' + CONVERT(char(1),@PartnNum)
		 
		-- Swap the TransLogLoad's new years partition's record set with the newly empty one from TransLog
		SELECT @TSQL += '
	ALTER TABLE ' + @LoadTableName + 
'
	SWITCH PARTITION ' + CONVERT(char(1),@PartnNum) + ' TO ' + @DestinationTableName + ' PARTITION ' + CONVERT(char(1),@PartnNum)
		 
	SELECT @TSQL += '
	TRUNCATE TABLE ' + @EmptyTableName
	
	-------------------------------------------------------------------------
	if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
	
	SELECT @StartTime = (@TempTime)
	SELECT @EndTime = (GETDATE())
	PRINT '--Execution time for usp_LoadTableUsingSwapPartitions: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)   
END
