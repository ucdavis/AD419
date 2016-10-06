-- =============================================
-- Author:		Ken Taylor
-- Create date: 01/06/2011
-- Description:	Loads a complete year's (or years') worth of a table's data records for both AAES and BIOS.
-- Defaults to the last three (3) years if the table is empty; otherwise the current year.
--
-- Usage: EXEC usp_Download_TableRecordsForFiscalYear
--
-- Modifications:
-- 20110118 by kjt: 
--		Revised setting of @RecordCount to be 0 and only use actual table record count if @TruncateTable = 0.
--		Changed logic from download 2 years of records to download 3 years of records. 
--		Added a parameter that will override the default number of years (3) to load into an empty table.
-- 20110120 by kjt: 
--		Added logic to disable non-pk and/or clustered index(es) if @DisableIndexes = 1.
--		Added logic to enable ALL indexes if @RebuildIndexes = 1.
-- 20110125 by kjt:
--		Fixed issue with all "IF @RebuildIndexes = 1" logic being within BEGIN and END statements.
-- 20110201 by kjt:
--		Modified date logic to function as intended.
-- 20110202 by kjt:
--		Added param @GetUpdatesOnly so this sproc could also be used by usp_UpdateFISDataMart in the future;
-- however, this only works correctly for a single year.
--		Added logic to bypass TruncateTable logic if @GetUpdatesOnly = 1
-- 20110203 by kjt:
--		Modified to pass a null argument to udf_GetBeginningAndLastFiscalYearToDownload for @Exclude9999FiscalYear.
-- 20110228 by kjt: 
--		Added '--' to @NumFiscalYearsToDownload print statement.
-- 20110302 by kjt:
--		Added comments and timing print outs
-- 20110323 by kjt:
--		Revised calls to underlying procedures to pass @TableName.
-- =============================================
CREATE Procedure [dbo].[usp_Download_TableRecordsForFiscalYear]
(
	--PARAMETERS:
	@TableName varchar(255) = null, --Name of the table to update 
	@DownloadSprocName varchar(255) = null, --Name of the download sproc to use for downloading records.
	@FirstDateString varchar(16) = null,	--earliest date to download 
		--optional, defaults to day after highest date in table
	@LastDateString varchar(16) = null,	--latest date to download 
		--optional, defaults to day after @FirstDate
	@NumYearsToDownload smallint = 3, --This applies to how many years to load into an empty table.
	@TruncateTable bit = 0, -- Set to 1 to truncate table before beginning merge process.
	@DisableIndexes bit = 0, --Set to 1 to disable all of the non-primary key and/or clustered index(es)
	@RebuildIndexes bit = 0, --Set to 1 to Rebuild/Enable ALL table indexes.
	@GetUpdatesOnly bit = 0, --Set to 1 to only get the updates, not all the records.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
    	--Downloads records for a range of posting dates
		--Makes use of pass-through queries to Oracle Linked Servers.
/*
DECLARE @TableName varchar(255) = 'Accounts', --Name of the table to update 
	@DownloadSprocName varchar(255) = 'usp_DownloadAccounts', --Name of the download sproc to use for downloading records.
	@FirstDateString varchar(16) = null, --'2009-07-01',	--earliest date to download 
		--optional, defaults to day after highest date in table
	@LastDateString varchar(16) = null, --'2011.06.30',	--latest date to download 
		--optional, defaults to day after @FirstDate
	@NumYearsToDownload smallint = 3, --This applies to how many years to load into an empty table.
	@TruncateTable bit = 1, -- Set to 1 to truncate table before beginning merge process.
	@DisableIndexes bit = 1, --Set to 1 to disable all of the non-primary key and/or clustered index(es)
	@RebuildIndexes bit = 0, --Set to 1 to Rebuild/Enable ALL table indexes.
	@IsDebug bit = 1 -- Set to 1 just print the SQL and not actually execute. 
*/

	--local:
	DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	DECLARE @BeginningFiscalYear int = null
	DECLARE @LastFiscalYearToDownload int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate dateTime = null
	DECLARE @Exclude9999FiscalYear bit = null --This is set in the individual called sprocs themselves.
	--------------------------------------------------------------------------------
	-- 20110302 by kjt: Stuff for timing print outs
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
	
	IF @IsDebug = 0
		PRINT '--Start time for EXEC usp_Download_TableRecordsForFiscalYear @TableName = ' + @TableName + ' using ' + @DownloadSprocName + ':
--' + CONVERT(varchar(20),@StartTime, 114)
	
	------------------------------------------------------------------------------------------------------------------
	-- Truncate table if selected:
	
	-- Do this first if requested before attempting to figure out date ranges:
	IF (@GetUpdatesOnly IS NULL OR @GetUpdatesOnly = 0) AND @TruncateTable = 1
		BEGIN
			SELECT @TSQL = '
	--Discarding all existing records from table:
	
	TRUNCATE TABLE [FISDataMart].[dbo].' + @TableName + '
	'
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
		END

	------------------------------------------------------------------------------------------------------------------
	-- Disable All non-PK and/or clustered indexes if selected:

	IF @DisableIndexes = 1
		BEGIN
			--Disabling All non-PK and/or clustered indexes...
			
			SELECT @TSQL = '
	EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = '''+ @TableName + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '

'	
			if @IsDebug = 1
				BEGIN
					--used for testing
					--PRINT '--' + @TSQL	
					EXEC(@TSQL)
				END
			else
				BEGIN
					--Execute the command:
					EXEC(@TSQL)
				END
	END

	------------------------------------------------------------------------------------------------------------------
	-- Main Logic to download table records:

	IF @GetUpdatesOnly = 1
		BEGIN
			-- This branch calls the underlying stored procedure once, as if had been called 
			-- directly unsing the default parameters, meaning "Get updates only mode".
			IF @IsDebug = 1
					BEGIN
						PRINT '
				--Making call to download ' + @TableName + ' records:
				--EXEC ' + @DownloadSprocName + ' @FirstDateString = ''' + ISNULL(CONVERT(char(4), @FirstDateString), '') + ''', @LastDateString = ''' +  ISNULL(CONVERT(char(4), @LastDateString), '') + ''', @GetUpdatesOnly = ' + CONVERT(char(1), @GetUpdatesOnly) + ', @TableName = ' + @TableName  + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
				  '
					END
					
				  SELECT @TSQL = 'EXEC ' + @DownloadSprocName + ' @FirstDateString = ''' + ISNULL(CONVERT(varchar(16), @FirstDateString), '') + ''', @LastDateString = ''' +  ISNULL(CONVERT(char(4), @LastDateString), '') + ''', @GetUpdatesOnly = ' + CONVERT(char(1), @GetUpdatesOnly) + ', @TableName = ' + @TableName + ', @IsDebug = ' + CONVERT(char(1),@IsDebug) + '
				  ' 
					
			-------------------------------------------------------------------------
			-- Execute SQL:
			
			if @IsDebug = 1
					BEGIN
						--used for testing
						--PRINT '--' + @TSQL	
						EXEC(@TSQL)
					END
				else
					BEGIN
						--Execute the command:
						EXEC(@TSQL)
						SELECT @StartTime = (@EndTime)
						SELECT @EndTime = (GETDATE())
						PRINT '--Executed in ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
					END
		END
	ELSE
		BEGIN
			-- This branch reloads the entire table a year at a time for the either the number of years
			-- specified by input param @NumYearsToDownload OR the number of years determined by the 
			-- input params @FirstDateString and @LastDateString.
			DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, FirstDate, LastDate, LastFiscalYearToDownload, NumFiscalYearsToDownload 
			FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
		
			OPEN MyCursor
		
			FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @FirstDate, @LastDate, @LastFiscalYearToDownload, @NumFiscalYearsToDownload
		
			CLOSE MyCursor
			DEALLOCATE MyCursor
		
			IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 

			print '--Making calls to download ' + @TableName + ' records...'

			DECLARE @DownloadFiscalYear int = @BeginningFiscalYear

			PRINT '--@DownloadFiscalYear: ' + ISNULL(CONVERT(char(4), @DownloadFiscalYear), 'NULL') + '
	--@LastFiscalYearToDownload: ' + ISNULL(CONVERT(char(4), @LastFiscalYearToDownload), 'NULL') + '
	'
			WHILE @DownloadFiscalYear <= @LastFiscalYearToDownload
				BEGIN
				  IF @GetUpdatesOnly = 0
					BEGIN
					  SELECT @FirstDateString = CONVERT(char(4), @DownloadFiscalYear -1) + '-07-01'
					  IF  @DownloadFiscalYear = @LastFiscalYearToDownload
						BEGIN
							SELECT @LastDateString = NULL
							PRINT '--Set @LastDateString = NULL'
						END
					  ELSE
						BEGIN
							SELECT @LastDateString  = CONVERT(char(4), @DownloadFiscalYear) + '-06-30'
						END
					END
				  ELSE
					BEGIN
						SELECT @FirstDateString = CONVERT(varchar(20), @FirstDate, 102)
						IF  @DownloadFiscalYear = @LastFiscalYearToDownload
							BEGIN
								SELECT @LastDateString = NULL
							END
						ELSE
							BEGIN
								SELECT @LastDateString = CONVERT(varchar(20), @LastDate, 102)
							END
					END
					
				  --Build Transact-SQL command:
					--Note: it doesn't work to build the SQL command and only pass in the Oracle SQL as a string--not if you want to parameterize the query.  The OPENQUERY() function apparently expects a string literal *only* for the 2nd argument (the SQL command) and will not work with any kind of character string built from variables.  The workaround is to build the entire t-SQL command as a varchar, and then execute it as a block of code by calling EXEC(<varchar>) with the entire block of code contained in the single parameter.  The trickiest part of doing this is that single quotes need to be escaped with 2 single quotes TWICE within the SQL for Oracle, meaning that you need to write the code with QUADRUPLE single quotes for every embedded quote you eventually want to pass thru to Oracle.  If the item to be inserted in quotes is a variable, then you need *5* single quotes, the 5th being used to close or open the strings being concatenated with the variable (/parameter).
				
				  --IF @IsDebug = 1
					BEGIN
						PRINT '
				--Making call to download ' + @TableName + ' records:
				--EXEC ' + @DownloadSprocName + ' @FirstDateString = ''' + CONVERT(char(4), @FirstDateString) + ''', @LastDateString = ''' +  ISNULL(CONVERT(char(4), @LastDateString), '') + ''', @GetUpdatesOnly = ' + CONVERT(char(1), @GetUpdatesOnly) + ', @TableName = ' + @TableName + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
				  '
					END
					
				  SELECT @TSQL = 'EXEC ' + @DownloadSprocName + ' @FirstDateString = ''' + CONVERT(varchar(16), @FirstDateString) + ''', @LastDateString = ''' +  ISNULL(CONVERT(char(4), @LastDateString), '') + ''', @GetUpdatesOnly = ' + CONVERT(char(1), @GetUpdatesOnly) + ', @TableName = ' + @TableName + ', @IsDebug = ' + CONVERT(char(1),@IsDebug) + '
				  ' 		
			-------------------------------------------------------------------------
			-- Execute SQL:

			if @IsDebug = 1
					BEGIN
						--used for testing
						--PRINT '--' + @TSQL	
						EXEC(@TSQL)
					END
				else
					BEGIN
						--Execute the command:
						EXEC(@TSQL)
						SELECT @StartTime = (@EndTime)
						SELECT @EndTime = (GETDATE())
						PRINT '--Executed in ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
					END
			Select @DownloadFiscalYear = @DownloadFiscalYear + 1
			END --While
		END --ELSE
		
	------------------------------------------------------------------------------------------------------------------
	-- Rebuild indexes if selected:
	
	IF @RebuildIndexes = 1
		BEGIN
			--Rebuild All table indexes...
				
				SELECT @TSQL = '
		EXEC usp_RebuildAllTableIndexes @TableName = ''' + @TableName + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '

	'		
		if @IsDebug = 1
			BEGIN
				--used for testing
				--PRINT '--' + @TSQL	
				EXEC(@TSQL)
			END
		else
			BEGIN
				--Execute the command:
				EXEC(@TSQL)
				SELECT @StartTime = (@EndTime)
				SELECT @EndTime = (GETDATE())
				PRINT '--Executed in ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
			END
	END
	
	IF @IsDebug = 0
		BEGIN
			SELECT @StartTime = (@TempTime)
			SELECT @EndTime = (GETDATE())
			PRINT '--Total Execution time Start time for EXEC usp_Download_TableRecordsForFiscalYear @TableName = ' + @TableName + ' using ' + @DownloadSprocName + ':
--' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
		END
