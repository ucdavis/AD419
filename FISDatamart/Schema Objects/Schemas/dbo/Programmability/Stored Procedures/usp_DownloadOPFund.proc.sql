/*
Modifications:
	2011-02-03 by kjt: 
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
		
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to OPFund.
	2015-03-12 by kjt:
		Added 2 new columns PromaryPIUserName, and ProjectTitle to load script.
	2016-03-15 by kjt:
		Added 1 new column CFDANum  to load script.
	2018-04-13 by kjt:
		Added 1 new column SponsorCode
	2018-07-25 by kjt:
		Added 1 new column PrimaryPIDaFISUserId
*/
CREATE PROCEDURE [dbo].[usp_DownloadOPFund]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.OP_FUND.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in Objects table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.OP_FUND.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'OPFund', --Can be passed another table name, i.e. #OPFund, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
declare @TSQL varchar(MAX)= ''--Holds T-SQL code to be run with EXEC() function.
DECLARE @WhereClause varchar(MAX) = '' -- Holds the T-SQL for the where clause.
/*
	If table is empty then we'll to derive a Fiscal Year based on today's date and
	an estimated closing date for a fiscal year of August 15th for the June Final (13th) period. 
	
	We'll need to handle max-date failure cases should the table be empty. 
*/
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'OPFund' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 0 --This is the only table with a 9999 fiscal year that we're not interested in. 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
	
-------------------------------------------------------------------------------------	
-- Build the Where clause based on the dates provided:
SELECT @WhereClause = 
'	OP_FUND.FISCAL_YEAR ' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
'>= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
'= ' + Convert(char(4), @BeginningFiscalYear)
END 											            

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
			AND (OP_FUND.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
				AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading OPFund records...'
	print '--Table ' + CASE WHEN @RecordCount = 0 THEN 'is EMPTY' ELSE 'has data' END
	print '--Earliest Date = ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102)
	print '--Latest Date = ' + convert(varchar(30),convert(smalldatetime,@LastDate),102)
	print '--Fiscal Year' + CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND @EndingFiscalYear <> 9999 THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
' >= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
 ' = ' + Convert(char(4), @BeginningFiscalYear)
END 		   
	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
-------------------------------------------------------------------------------------
select @TSQL = 
'
merge ' + @TableName + ' as OPFund 
using
(
SELECT 
	fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	award_begin_date,
	award_end_date,
	award_amt,
	LAST_UPDATE_DATE,
	OP_Fund_PK,
	sub_fund_group_FK,
	PRIMARY_PI_USER_NAME, 
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID

 FROM OPENQUERY(FIS_DS, 
	''SELECT 
    fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	PRIMARY_PI_USER_NAME, 
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID,
	TO_CHAR(award_begin_date, ''''yyyy-mm-dd hh:mm:ss.sssss'''') award_begin_date,
	TO_CHAR(award_end_date, ''''yyyy-mm-dd hh:mm:ss.sssss'''') award_end_date,
	award_amt,
	ds_last_update_date LAST_UPDATE_DATE,
	fiscal_year || ''''|'''' || fiscal_period || ''''|'''' || op_location_code || ''''|'''' || op_fund_num as OP_Fund_PK,
	fiscal_year || ''''|'''' || fiscal_period || ''''|'''' || sub_fund_group_num as sub_fund_group_FK
	
	FROM FINANCE.OP_FUND
	WHERE 
		' + @WhereClause + '
	'')
) FIS_DS_OP_FUND on OPFund.OPFundPK = FIS_DS_OP_FUND.OP_Fund_PK

WHEN MATCHED THEN UPDATE set
	   [FundName] = op_fund_name
      ,[FundGroupCode] = op_fund_group_code
      ,[FundGroupName] = op_fund_group_name
      ,[SubFundGroupNum] = sub_fund_group_num
      ,[AwardNum] = award_num
      ,[AwardType] = award_type_code
      ,[AwardYearNum] = award_year_num
      ,[AwardBeginDate] = award_begin_date
      ,[AwardEndDate] =  award_end_date
      ,[AwardAmount] = award_amt
      ,[LastUpdateDate] = Convert(smalldatetime, LAST_UPDATE_DATE, 120)
      ,[SubFundGroupFK] = sub_fund_group_FK
	  ,PrimaryPIUserName = PRIMARY_PI_USER_NAME
	  ,ProjectTitle = PROJECT_TITLE
	  ,CFDANum	=	CFDA_NUM
	  ,SponsorCode = SPONSOR_CODE
	  ,PrimaryPIDaFISUserId = PRIMARY_PI_DAFIS_USER_ID
     
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
(
	fiscal_year,
	fiscal_period,
	op_location_code,
	op_fund_num,
	op_fund_name,
	op_fund_group_code,
	op_fund_group_name,
	sub_fund_group_num,
	award_num,
	award_type_code,
	award_year_num,
	award_begin_date,
	award_end_date,
	award_amt,
	Convert(smalldatetime, LAST_UPDATE_DATE, 120),
	OP_Fund_PK,
	sub_fund_group_FK,
	PRIMARY_PI_USER_NAME, 
	PROJECT_TITLE,
	CFDA_NUM,
	SPONSOR_CODE,
	PRIMARY_PI_DAFIS_USER_ID
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
'

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
