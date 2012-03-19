-- =============================================
-- Author:		Ken Taylor
-- Create date: January 18, 2011
-- Description:	This is a generic function that returns a table containing BeginningFiscalYear,
-- and LastFiscalYear (to download) to be used in multi-year table downloads.
-- Modifications:
--		2011-02-03 by kjt:
--			Added parameter to disable 9999 year.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetBeginningAndLastFiscalYearToDownload] 
(
	-- Add the parameters for the function here
	@TableName varchar(255) = '', --The name of the table you desire to download records into.
	@FirstDateString varchar(16) = null, --earliest date to download (FINANCE.ORGANIZATION_ACCOUNT.DS_LAST_UPDATE_DATE) 
		--optional, defaults to day after highest date in Trans table
	@LastDateString varchar(16) = null,	--latest date to download 
		--optional, defaults to day after @FirstDate
	@NumYearsToDownload smallint = 3, --This applies to how many years to load into an empty table.
	@TruncateTable bit = 0,
	@Exclude9999FiscalYear bit = 0 --Setting this to 1 will NOT return 9999 as the EndingFiscalYear as appropriate.
	-- Instead, it will use the last actual fiscal year determined, i.e. 2011, etc.
)
RETURNS 
@DownloadDatesTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	BeginningFiscalYear int, 
	EndingFiscalYear int,
	LastFiscalYearToDownload int,
	NumFiscalYearsToDownload smallint,
	FirstDate datetime,
	LastDate dateTime,
	TruncateTable bit,
	RecordCount int
)
AS
BEGIN
--local:
	declare @TSQL nvarchar(MAX)	--Holds T-SQL code to be run with EXEC() function.
	DECLARE @RecordCount int = 0
	DECLARE @MaxLastUpdateDate datetime 
	DECLARE @FirstDate datetime = null
	Declare @HasBeginningDate bit = 0
	DECLARE @LastDate datetime = null
	Declare @HasEndingDate bit = 0
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @FiscalYear int = null
	DECLARE @RunStatus int = null
	
	--Note regarding date formats: Need to pass date to Oracle using it's conversion function TO_DATE, for which a string type is need.  I'm using a varchar for the parameters here, but convert to a smalldatetime in order to make use of the DateAdd() function and formatting options in the conversion function CONVERT. (which I use to convert back to a char type for conversion to the Oracle date type.
	
	IF @NumYearsToDownload IS NULL OR @NumYearsToDownload = 0
		SELECT @NumYearsToDownload = 3
	
	-- Do this first if requested before attempting to figure out date ranges:
	IF @TruncateTable = 0
		BEGIN
			SELECT @RecordCount = (Select Count FROM TableNameMaxLastUpdateDateCountV
			WHERE TableName = @TableName)
		END
	
	--TESTING
	--set @firstDate = '10/10/06'
	
-- Figure out the starting date value:
IF @FirstDateString IS NULL OR @FirstDateString = ''
	IF @RecordCount = 0
		BEGIN
			-- Table is empty so use today's date:
			Select @FirstDate = GETDATE()
		END
	ELSE
		BEGIN
			-- Table is NOT empty so use the MAX (Last)UpdateDate from the table:
			Select @FirstDate = (
				SELECT cast(LastUpdateDate as smalldatetime) as MaxLastUpdateDate
				FROM TableNameMaxLastUpdateDateCountV WHERE TableName = @TableName)
		END
ELSE 
	BEGIN
		-- Otherwise use @FirstDateProvided:
		Select @HasBeginningDate = 1
		Select @FirstDate = convert(smalldatetime,@FirstDateString)
	END
		
-- Figure out the ending date value:
IF @LastDateString IS NULL OR @LastDateString = ''
	BEGIN
		-- Use current date as @LastDate
		Select @LastDate = GETDATE()
	END
ELSE
	BEGIN
		-- Otherwise use @LastDateProvided:
		Select @HasEndingDate = 1
		Select @LastDate = convert(smalldatetime,@LastDateString)
	END
		
-------------------------------------------------------------------------------------
-- This next section of logic deals with swapping the @FirstDate and @LastDate if the 
-- user entered them in reverse order:
DECLARE @TempDate datetime = @LastDate
IF (@FirstDate > @LastDate)
	BEGIN
		-- Swap first date with last date:
		Select @LastDate = @FirstDate
		Select @FirstDate = @TempDate 
				
		IF (@HasBeginningDate = 1 OR @HasEndingDate = 1)
			BEGIN
				-- Swap the @HasBeginningDate and @HasEndingDate flags
				-- if any dates were provided:
				Declare @TempHasDate int = @HasEndingDate
				Select @HasEndingDate = @HasBeginningDate
				Select @HasBeginningDate = @TempHasDate
			END
	END
	
-------------------------------------------------------------------------------------
-- Now that we have the dates set correctly and with a @FirstDate <= @LastDate, 
-- set the @BeginningFiscalYear and @EndingFiscalYear values accordingly:

-- Set the @BeginningFiscalYear:
IF @HasBeginningDate = 0
	BEGIN
		-- If a beginning date was not provided:
		IF @RecordCount = 0
			BEGIN
				-- Table is empty
				Select @BeginningFiscalYear = (
					CASE WHEN (MONTH(@FirstDate) >= 1 AND MONTH(@FirstDate) < 8) OR (MONTH(@FirstDate) = 8 AND DAY(@FirstDate) <= 15) THEN YEAR(@FirstDate) - 1
					ELSE YEAR(@FirstDate)  
					END)
				-- Set beginning fiscal year back another year in order to get three years of data: 
				Select @BeginningFiscalYear = @BeginningFiscalYear - (@NumYearsToDownload - 2) 
			END
		ELSE
			BEGIN
				-- Table is not empty so set the @BeginningFiscalYear using the fiscal year logic below:
				Select @BeginningFiscalYear = (CASE WHEN (MONTH(@FirstDate) >= 1 AND MONTH(@FirstDate) < 8) OR (MONTH(@FirstDate) = 8 AND DAY(@FirstDate) <= 15) THEN YEAR(@FirstDate)
					ELSE YEAR(@FirstDate) + 1
					END)
			END
	END
ELSE
	BEGIN
		-- A beginning date was provide so set the @BeginningFiscalYear using the fiscal year logic below:
			Select @BeginningFiscalYear = (
				CASE WHEN (MONTH(@FirstDate) >= 1 AND MONTH(@FirstDate) < 6) OR (MONTH(@FirstDate) = 6 AND DAY(@FirstDate) <= 30) THEN YEAR(@FirstDate)
				ELSE YEAR(@FirstDate) + 1 
				END)
	END

-- Set the @EndingFiscalYear

	IF @HasEndingDate = 0 AND @Exclude9999FiscalYear = 0
		BEGIN
			-- Set the @EndingFiscalYear to 9999 if a @LastDate was not provided and not excluded
			Select @EndingFiscalYear = 9999
		END
	ELSE
		BEGIN
			-- Otherwise, set the EndingFiscalYear using the fiscal year logic listed below:
			Select @EndingFiscalYear = (
				CASE WHEN (MONTH(@LastDate) >=1 AND MONTH(@LastDate) < 6 ) OR (MONTH(@LastDate) = 6 AND DAY(@LastDate) <= 30) THEN YEAR(@LastDate)
				ELSE YEAR(@LastDate) +1 
				END)
		END

	
-- How many fiscal years do we download?
DECLARE @LastFiscalYearToDownload int
Select @LastFiscalYearToDownload = (
			CASE WHEN (MONTH(@LastDate) >=1 AND MONTH(@LastDate) < 6) OR (MONTH(@LastDate) = 6 AND DAY(@LastDate) <= 30) THEN YEAR(@LastDate)
			ELSE YEAR(@LastDate) +1 
			END)

DECLARE @NumFiscalYearsToDownload int = @LastFiscalYearToDownload - @BeginningFiscalYear +1	

		INSERT INTO @DownloadDatesTable(BeginningFiscalYear, EndingFiscalYear, LastFiscalYearToDownload, NumFiscalYearsToDownload, FirstDate, LastDate, TruncateTable, RecordCount)
		SELECT @BeginningFiscalYear, @EndingFiscalYear, @LastFiscalYearToDownload, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @TruncateTable, @RecordCount
	RETURN 
END
