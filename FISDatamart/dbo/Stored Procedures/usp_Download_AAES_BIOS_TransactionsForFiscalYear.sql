-- =============================================
-- Author:		Ken Taylor
-- Create date: 01/06/2011
-- Description:	Loads a complete year's (or years') worth of transactional data for both AAES and BIOS.
-- Defaults to the last three (3) years if the table is empty; otherwise the current year.
--
-- Notes: Disables all but clustered and PKTrans indexes, and then re-enables and rebuilds after the
-- process is complete.
-- Use the companion sproc usp_DownloadTransactionsForFiscalYear to load records for a single org only.
--
-- Usage: EXEC usp_Download_AAES_BIOS_TransactionsForFiscalYear
--
-- Modifications:
-- 20110118 by kjt: 
--		Revised setting of @RecordCount to be 0 and only use actual table record count if @TruncateTable = 0.
--		Changed logic from download 2 years of records to download 3 years of records. 
--		Added a parameter that will override the default number of years (3) to load into an empty table.
-- 2011-02-01 by kjt: 
--		Removed all date determination logic and replaced it with a call to udf_GetBeginningAndLastFiscalYearToDownload.
-- 2011-02-03 by kjt:
--		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
--		@Exclude9999FiscalYear.
-- 2011-02-07 by kjt:
--		Added params @DisableIndexes, and @RebuildIndexes to allow for disabling/enabling indexes.
--		Added missing variables necessary for cursor variable retrieval:  @RecordCount,
--		@FirstDate datetime, @LastDate,  @EndingFiscalYear.
--
-- =============================================
CREATE Procedure [dbo].[usp_Download_AAES_BIOS_TransactionsForFiscalYear]
(
	--PARAMETERS:
	@FirstDateString varchar(16) = null,	--earliest date to download (GL_Applied.TRANS_GL_POSTED_DATE) 
		--optional, defaults to day after highest date in Trans table
	@LastDateString varchar(16) = null,	--latest date to download 
		--optional, defaults to day after @FirstDate
	@NumYearsToDownload smallint = 3, --This applies to how many years to load into an empty table.
	@TruncateTable bit = 0, -- Set to 1 to truncate table before beginning merge process.
	@DisableIndexes bit = 1, --Set to 0 to NOT disable the indexes before loading.
	@RebuildIndexes bit = 0, -- Set to 1 to enable/rebuild the indexes after loading table.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS
	--Downloads GL_Applied (applied transactions) records for a range of posting dates
	--Makes use of pass-through queries to Oracle Linked Servers.

	--local:
--local:
	DECLARE @TSQL varchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	DECLARE @RecordCount int = 0
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @LastFiscalYearToDownload int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @TableName varchar(255) = 'Trans' --The name of the table this sproc is updating.
	DECLARE @Exclude9999FiscalYear bit = 1 --This table does not have FY 9999 data so interested in. 
	
	DECLARE @IsCAES bit -- to flag whether or not transaction is under CAES and not Bio Sci. 
	     
    -- 20100721 by KJT: I added these because Steve Pesis' said that there are now orgs in 
    -- AAES that belong to BIOS, and BIOS orgs that are outside of BIOS; therefore, 
    -- we need to readjust the 'IsCAES' logic to handle this.
    -- 20100804 by KJT: Revised above logic to set the Is_CAES based on the input org
    -- as Tom Kaiser says that the ACBS amounts should be included as part of the 
    -- AAES base budget; however, I believe that Steve Pesis doesn't want them for
    -- some of his reports.
	declare @AAES char(4) = 'AAES'
	declare @BIOS char(4) = 'BIOS' 
	declare @ACBS char(4) = 'ACBS'
	
	-- Do this first if requested before attempting to figure out date ranges:
	IF @TruncateTable = 1
		BEGIN
			SELECT @TSQL = '
	PRINT ''--Discarding all existing records from table...''
	
	TRUNCATE TABLE [FISDataMart].[dbo].[Trans]'
	
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

-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, LastFiscalYearToDownload, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @LastFiscalYearToDownload, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1 
		BEGIN
			PRINT '@TruncateTable: ' + CONVERT(char(1), @TruncateTable)
			PRINT '@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload)
			PRINT '@BeginningFiscalYear: ' + ISNULL(Convert(varchar(4), @BeginningFiscalYear), 'NULL')
			PRINT '@EndingFiscalYear: ' + ISNULL(Convert(varchar(4), @EndingFiscalYear), 'NULL')
			PRINT '@LastFiscalYearToDownload: ' + ISNULL(Convert(varchar(4), @LastFiscalYearToDownload), 'NULL')
			PRINT '@FirstDate: ' + ISNULL(Convert(varchar(20), @FirstDate), 'NULL')
			PRINT '@LastDate: ' + ISNULL(Convert(varchar(20), @LastDate), 'NULL')
			PRINT '@RecordCount: ' + Convert(varchar(20), @RecordCount) 
		END
-------------------------------------------------------------------------------------
	-- Disable indexes as specified:	
	IF @DisableIndexes = 1
		BEGIN
			SELECT @TSQL = '
    EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '			
			'
			EXEC(@TSQL)
		END
	
	print '--Making calls to download transaction records...'
	--print '--' + convert(varchar(30),convert(smalldatetime,@FirstDate),102) + ' = First date'
	--print '--' + convert(varchar(30),convert(smalldatetime,@LastDate),102) + ' = Last date'

DECLARE @DownloadFiscalYear int = @BeginningFiscalYear

PRINT '--@DownloadFiscalYear: ' + ISNULL(CONVERT(char(4), @DownloadFiscalYear), 'NULL') + '
--@LastFiscalYearToDownload: ' + ISNULL(CONVERT(char(4), @LastFiscalYearToDownload), 'NULL') + '
'

WHILE @DownloadFiscalYear <= @LastFiscalYearToDownload
BEGIN
	--Build Transact-SQL command:
		--Note: it doesn't work to build the SQL command and only pass in the Oracle SQL as a string--not if you want to parameterize the query.  The OPENQUERY() function apparently expects a string literal *only* for the 2nd argument (the SQL command) and will not work with any kind of character string built from variables.  The workaround is to build the entire t-SQL command as a varchar, and then execute it as a block of code by calling EXEC(<varchar>) with the entire block of code contained in the single parameter.  The trickiest part of doing this is that single quotes need to be escaped with 2 single quotes TWICE within the SQL for Oracle, meaning that you need to write the code with QUADRUPLE single quotes for every embedded quote you eventually want to pass thru to Oracle.  If the item to be inserted in quotes is a variable, then you need *5* single quotes, the 5th being used to close or open the strings being concatenated with the variable (/parameter).
	
	  IF @IsDebug = 1
		BEGIN
			PRINT '
	--Making call to download transaction records:
	--EXEC usp_DownloadTransactionsForFiscalYear @FiscalYear = ' + CONVERT(char(4), @DownloadFiscalYear) + ', @CollegeOrg = ''' + @AAES + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	  '
		END
	  
	  PRINT '--Making call to download transaction records for AAES ' + CONVERT(char(4), @DownloadFiscalYear) + ' fiscal year...
	  '
	  EXEC usp_DownloadTransactionsForFiscalYear @FiscalYear = @DownloadFiscalYear ,
	  @CollegeOrg = @AAES, @IsDebug = @IsDebug
		
	 print ''
	  IF @IsDebug = 1
		BEGIN
			PRINT '
	--Making call to download transaction records:
	--EXEC usp_DownloadTransactionsForFiscalYear @FiscalYear = ' + CONVERT(char(4), @DownloadFiscalYear) + ', @CollegeOrg = ''' + @BIOS + ''', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	  '
		END
	  	
	  PRINT '--Making call to download transaction records for BIOS ' + CONVERT(char(4), @DownloadFiscalYear) + ' fiscal year...
	  '	
	  EXEC usp_DownloadTransactionsForFiscalYear @FiscalYear = @DownloadFiscalYear,
	  @CollegeOrg = @BIOS, @IsDebug = @IsDebug
		
-------------------------------------------------------------------------

--if @IsDebug = 1
--		BEGIN
--			--used for testing
--			PRINT @TSQL	
--		END
--	else
--		BEGIN
--			--Execute the command:
--			EXEC(@TSQL)
--		END
Select @DownloadFiscalYear = @DownloadFiscalYear + 1
END --While

	-- Enable/Rebuild All Indexes:
    IF @RebuildIndexes = 1
		BEGIN
			SELECT @TSQL = '
    EXEC usp_RebuildAllTableIndexes @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '			
			'
			EXEC(@TSQL)
		END