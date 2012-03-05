-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-01-06
-- Description:	Delete all records from the named table provided, one period at a time,
-- meeting the date criteria determined from the input parameters.
--
-- Note that this sproc assumes that the Fiscal Year and Fiscal Period 
-- are named Year and Period; otherwise set @UseFiscalPerfix to 1
--
-- Modifications:
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_DeleteFromTableUsingPeriods] 
	@FirstDateString varchar(16) = null,
		--earliest date to download  
		--optional, defaults to highest date in table
	@LastDateString varchar(16) = null,
		-- latest date to download 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- This parameter is just a placeholder so that it can be called
		-- using usp_Download_TableRecordsForFiscalYear.
	@TableName varchar(255) = 'TransLog', --Can be passed another table name, i.e. #TransLog, etc.
	@UseFiscalPrefix bit = 0, --Set this to 1 to prefix Year and Period with Fiscal, i.e. FiscalYear, etc.
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
	
	IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
-------------------------------------------------------------------------------------	
	SELECT @WhereClause = 
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          (@EndingFiscalYear <> 9999 AND @EndingFiscalYear <> 1900) THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN (@EndingFiscalYear = 9999 OR @EndingFiscalYear = 1900) THEN
' >= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
' = ' + Convert(char(4), @BeginningFiscalYear)
END 
	
-- Insert Periods into @MyTable:
DECLARE @MyTable TABLE (Period char(2))
DECLARE @Period char(2)
INSERT INTO @MyTable VALUES ('01'), ('02'), ('03'), ('04'), ('05'), ('06'), ('07'), ('08'), ('09'), ('10'), ('11'), ('12'), ('13')

DECLARE myCursor CURSOR FOR SELECT * FROM @MyTable
OPEN myCursor
FETCH NEXT FROM myCursor INTO @Period

WHILE @@FETCH_STATUS <> -1
BEGIN

	select @TSQL = 
	'
DELETE FROM 
	' + @TableName + '
WHERE 
	' 
	IF @UseFiscalPrefix = 1
		SELECT @TSQL += 'Fiscal'
		  
	SELECT @TSQL+= 'Year' + @WhereClause + ' AND '
	
	IF @UseFiscalPrefix = 1
		SELECT @TSQL += 'Fiscal'
		
	SELECT @TSQL += 'Period = ''' + @Period + '''
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
		
FETCH NEXT FROM myCursor INTO @Period		
END

CLOSE myCursor
DEALLOCATE myCursor

END
