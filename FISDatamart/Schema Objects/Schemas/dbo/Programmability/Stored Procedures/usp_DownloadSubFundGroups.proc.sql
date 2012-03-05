/*
Modifications:
	2011-02-03 by kjt:
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to SubFundGroups.
*/
CREATE Procedure [dbo].[usp_DownloadSubFundGroups]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.SubFundGroups.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in SubFundGroups table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.SubFundGroups.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'SubFundGroups', --Can be passed another table name, i.e. #SubFundGroups, etc.
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
DECLARE @RecordCount int = 0
DECLARE @FirstDate datetime = null
DECLARE @LastDate datetime = null
DECLARE @BeginningFiscalYear int = null
DECLARE @EndingFiscalYear int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	--DECLARE @TableName varchar(255) = 'SubFundGroups' --Name of table being updated.
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
	
	IF @IsDebug = 1 PRINT '@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
			
-------------------------------------------------------------------------------------	
-- Build the Where clause based on the dates provided:
SELECT @WhereClause = 
'SUB_FUND_GROUP.FISCAL_YEAR ' +
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
					AND SUB_FUND_GROUP.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
						AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd'''')'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading SubFundGroups records...'
	print '--Table ' + CASE WHEN @RecordCount = 0 THEN 'is EMPTY' ELSE 'has data' END
	print '--Earliest Date = ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102)
	print '--Latest Date = ' + convert(varchar(30),convert(smalldatetime,@LastDate),102)
	print '--Fiscal Year' + CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
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
Print ''-- Merging table dbo.SubFundGroups...''
merge ' + @TableName + ' as SubFundGroups
using
(
SELECT 
	   [Year]
      ,[Period]
      ,[SubFundGroupNum]
      ,[SubFundGroupName]
      ,[FundGroupCode]
      ,[SubFundGroupType]
      ,[SubFundGroupActiveIndicator]
      ,[LastUpdateDate]
      ,[SubFundGroupRestrictionCode]
      ,[OPUnexpendedBalanceAccount]
      ,[OPFundGroup]
      ,[OPOverheadClearingAccount]
      ,[SubFundGroupPK]
 FROM OPENQUERY(FIS_DS, 
	''SELECT 
    fiscal_year Year,
	fiscal_period Period,
	sub_fund_group_num SubFundGroupNum,
	sub_fund_group_desc SubFundGroupName,
	fund_group_code FundGroupCode,
	sub_fund_group_type_code SubFundGroupType,
	active_ind SubFundGroupActiveIndicator,
	ds_last_update_date LastUpdateDate,
	restriction_code SubFundGroupRestrictionCode,
	op_unexpended_balance_acct_num OPUnexpendedBalanceAccount,
	op_fund_group_code OPFundGroup,
	op_overhead_clearing_acct_num OPOverheadClearingAccount,
	fiscal_year || ''''|'''' || fiscal_period || ''''|'''' || sub_fund_group_num as SubFundGroupPK
	FROM FINANCE.SUB_FUND_GROUP
	WHERE ' + @WhereClause + '
	ORDER BY SubFundGroupNum
				'')
) FIS_DS_SUB_FUND_GROUP on SubFundGroups.SubFundGroupPK = FIS_DS_SUB_FUND_GROUP.SubFundGroupPK

WHEN MATCHED THEN UPDATE set
       [SubFundGroupName] = FIS_DS_SUB_FUND_GROUP.[SubFundGroupName]
      ,[FundGroupCode] = FIS_DS_SUB_FUND_GROUP.FundGroupCode
      ,[SubFundGroupType] = FIS_DS_SUB_FUND_GROUP.SubFundGroupType
      ,[SubFundGroupActiveIndicator] = FIS_DS_SUB_FUND_GROUP.SubFundGroupActiveIndicator
      ,[LastUpdateDate] = FIS_DS_SUB_FUND_GROUP.LastUpdateDate
      ,[SubFundGroupRestrictionCode] = FIS_DS_SUB_FUND_GROUP.SubFundGroupRestrictionCode
      ,[OPUnexpendedBalanceAccount] = FIS_DS_SUB_FUND_GROUP.OPUnexpendedBalanceAccount
      ,[OPFundGroup] = FIS_DS_SUB_FUND_GROUP.OPFundGroup
      ,[OPOverheadClearingAccount] = FIS_DS_SUB_FUND_GROUP.OPOverheadClearingAccount
 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	  [Year]
      ,[Period]
      ,[SubFundGroupNum]
      ,[SubFundGroupName]
      ,[FundGroupCode]
      ,[SubFundGroupType]
      ,[SubFundGroupActiveIndicator]
      ,[LastUpdateDate]
      ,[SubFundGroupRestrictionCode]
      ,[OPUnexpendedBalanceAccount]
      ,[OPFundGroup]
      ,[OPOverheadClearingAccount]
      ,[SubFundGroupPK]
)

--WHEN NOT MATCHED BY SOURCE THEN DELETE
;'

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
