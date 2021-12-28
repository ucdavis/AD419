/*
Modifications:
20110613 by kjt: Revised to use Organization accounts where appropriate because 
	GeneralLedgerProjectBalancesForAllPeriods table fields were coming back null and the
	load process was failing for account ALTHAY1.
2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE PROCEDURE [dbo].[usp_DownloadGeneralLedgerProjectBalancesForAllPeriods]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.GL_PROJECT_BAL_ALL_PERIOD.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in GeneralLedgerPeriodBalances table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.GL_PROJECT_BAL_ALL_PERIOD.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'GeneralLedgerProjectBalanceForAllPeriods', --Can be passed another table name, i.e. #GeneralLedgerPeriodBalances, etc.
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
-------------------------------------------------------------------------------------
	DECLARE @NumFiscalYearsToDownload smallint = null
	--DECLARE @TableName varchar(255) = 'GeneralLedgerProjectBalanceForAllPeriods' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 1 --This is the only table with a 9999 fiscal year that we're not interested in. 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1
		BEGIN
			Print 'Beginning Fiscal Year: ' + CONVERT(varchar(20), @BeginningFiscalYear)
			Print 'Ending Fiscal Year: ' + CONVERT(varchar(20), @EndingFiscalYear)
			Print 'NumFiscalYearsToDownload: ' + CONVERT(varchar(20), @NumFiscalYearsToDownload)
			Print 'FirstDate: ' + CONVERT(varchar(20), @FirstDate)
			Print 'LastDate: ' + CONVERT(varchar(20), @LastDate)
			Print 'RecordCount: ' + CONVERT(varchar(20), @RecordCount)
		END
-------------------------------------------------------------------------------------	
-- Build the Where clause based on the dates provided:
DECLARE @FiscalYearClause varchar(1024)= 
	CASE WHEN (@BeginningFiscalYear <> @EndingFiscalYear) THEN
		 'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
	ELSE
		'= ' + Convert(char(4), @BeginningFiscalYear) 
	END
	
SELECT @WhereClause = 
'	GL_ProjectBalAllPeriod.FISCAL_YEAR ' +
CASE WHEN (@BeginningFiscalYear <> @EndingFiscalYear) THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
ELSE
'= ' + Convert(char(4), @BeginningFiscalYear)
END 												            
	+	'
				AND GL_ProjectBalAllPeriod.object_num NOT IN ( ''''0054'''',''''9998'''',''''HIST'''' )
                AND GL_ProjectBalAllPeriod.balance_type_code IN ( ''''CB'''', ''''AC'''', ''''EX'''', ''''IE'''' )
				'

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
	        	AND (GL_ProjectBalAllPeriod.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
					AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading GeneralLedgerProjectBalanceForAllPeriods records...'
	print '--Table ' + CASE WHEN @RecordCount = 0 THEN 'is EMPTY' ELSE 'has data' END
	print '--Earliest Date = ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102)
	print '--Latest Date = ' + convert(varchar(30),convert(smalldatetime,@LastDate),102)
	print '--Fiscal Year' + CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + Convert(char(4), @EndingFiscalYear)
ELSE
' = ' + Convert(char(4), @BeginningFiscalYear)
END 												      
	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
		
select @TSQL = 
'
merge ' + @TableName + ' as GeneralLedgerProjectBalanceForAllPeriods
using
(
SELECT
     FISCAL_YEAR
	,CHART_NUM	
	,ORG_ID	
	,ACCT_TYPE_CODE	
	,ACCT_NUM	
	,SUB_ACCT_NUM
	,OBJ_CONSOLIDATN_NUM			
	,OBJECT_NUM	
	,SUB_OBJECT_NUM	
	,PROJECT_NUM
	,BALANCE_TYPE_CODE
	,BALANCE_TYPE_NAME
	,OBJECT_TYPE_CODE
	,SUB_FUND_GROUP_TYPE_CODE
	,BALANCE_CREATE_DATE
	,YTD_ACTUAL_AMT	
	,FISCAL_YEAR_BEGIN_BAL	
	,CONTRACTS_AND_GRANTS_BEGIN_BAL
	,JUL_TRANS_TOTAL_AMT
	,AUG_TRANS_TOTAL_AMT
	,SEP_TRANS_TOTAL_AMT
	,OCT_TRANS_TOTAL_AMT
	,NOV_TRANS_TOTAL_AMT
	,DEC_TRANS_TOTAL_AMT
	,JAN_TRANS_TOTAL_AMT
	,FEB_TRANS_TOTAL_AMT
	,MAR_TRANS_TOTAL_AMT
	,APR_TRANS_TOTAL_AMT
	,MAY_TRANS_TOTAL_AMT
	,JUN_TRANS_TOTAL_AMT
	,MONTH13_TRANS_TOTAL_AMT
	,LAST_UPDATE_DATE
FROM OPENQUERY (FIS_DS, 
			''SELECT 	
	 OA.FISCAL_YEAR
	,OA.CHART_NUM	
	,OA.ORG_ID	
	,OA.ACCT_TYPE_CODE	
	,OA.ACCT_NUM	
	,GL_ProjectBalAllPeriod.SUB_ACCT_NUM
	,GL_ProjectBalAllPeriod.OBJ_CONSOLIDATN_NUM			
	,GL_ProjectBalAllPeriod.OBJECT_NUM	
	,GL_ProjectBalAllPeriod.SUB_OBJECT_NUM	
	,GL_ProjectBalAllPeriod.PROJECT_NUM
	,GL_ProjectBalAllPeriod.BALANCE_TYPE_CODE
	,GL_ProjectBalAllPeriod.BALANCE_TYPE_NAME
	,GL_ProjectBalAllPeriod.OBJECT_TYPE_CODE
	,OA.SUB_FUND_GROUP_TYPE_CODE
	,GL_ProjectBalAllPeriod.BALANCE_CREATE_DATE
	,GL_ProjectBalAllPeriod.YTD_ACTUAL_AMT	
	,GL_ProjectBalAllPeriod.FISCAL_YEAR_BEGIN_BAL	
	,GL_ProjectBalAllPeriod.CONTRACTS_AND_GRANTS_BEGIN_BAL
	,GL_ProjectBalAllPeriod.JUL_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.AUG_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.SEP_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.OCT_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.NOV_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.DEC_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.JAN_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.FEB_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.MAR_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.APR_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.MAY_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.JUN_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.MONTH13_TRANS_TOTAL_AMT
	,GL_ProjectBalAllPeriod.DS_LAST_UPDATE_DATE AS LAST_UPDATE_DATE
			from FINANCE.GL_PROJECT_BAL_ALL_PERIOD GL_ProjectBalAllPeriod
			INNER JOIN FINANCE.ORGANIZATION_ACCOUNT OA ON
				GL_ProjectBalAllPeriod.FISCAL_YEAR = OA.FISCAL_YEAR AND
				GL_ProjectBalAllPeriod.CHART_NUM = OA.CHART_NUM AND
				GL_ProjectBalAllPeriod.ACCT_NUM = OA.ACCT_NUM AND
				OA.FISCAL_PERIOD = ''''--''''
			INNER JOIN
			(
				SELECT DISTINCT CHART_NUM, ORG_ID
				FROM FINANCE.ORGANIZATION_HIERARCHY Orgs
				WHERE 
					(
						(Orgs.CHART_NUM_LEVEL_1 = ''''3'''' and Orgs.ORG_ID_LEVEL_1 = ''''AAES'''')
						OR
						(Orgs.ORG_ID_LEVEL_1 = ''''BIOS'''')
						OR
						(Orgs.CHART_NUM_LEVEL_2 = ''''L'''' and Orgs.ORG_ID_LEVEL_2 = ''''AAES'''')
						OR 
						(Orgs.CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND Orgs.ORG_ID_LEVEL_4 = ''''AAES'''')
						OR
						(Orgs.ORG_ID_LEVEL_4 = ''''BIOS'''')
						OR
						(Orgs.CHART_NUM_LEVEL_5 = ''''L'''' AND Orgs.ORG_ID_LEVEL_5 = ''''AAES'''')
					)
					AND FISCAL_YEAR ' + @FiscalYearClause + '
			
			) Orgs ON OA.CHART_NUM = Orgs.CHART_NUM AND OA.ORG_ID = Orgs.ORG_ID
			WHERE 
			' + @WhereClause + '
		'')
) FIS_DS_GL_PROJECT_BAL_ALL_PERIOD on 
    Year = FISCAL_YEAR 
AND Chart = CHART_NUM
AND OrgID = ORG_ID
AND Account = ACCT_NUM
AND CONVERT(char(5), SubAccount) = SUB_ACCT_NUM
AND Object = OBJECT_NUM
AND SubObject = SUB_OBJECT_NUM
AND Project = PROJECT_NUM 
AND BalType = BALANCE_TYPE_CODE
AND ObjectType = OBJECT_TYPE_CODE

WHEN MATCHED THEN UPDATE set
	   [AccountType]							= ACCT_TYPE_CODE
      ,[ObjectConsolidatnNum]					= OBJ_CONSOLIDATN_NUM
      ,[BalTypeName]							= BALANCE_TYPE_NAME
      ,[SubFundGroupType]						= SUB_FUND_GROUP_TYPE_CODE
      ,[BalanceCreateDate]						= BALANCE_CREATE_DATE
      ,[YearToDateActualBalance]				= YTD_ACTUAL_AMT
      ,[FiscalYearBeginningBalance]				= FISCAL_YEAR_BEGIN_BAL
      ,[ContractsAndGrantsBeginningBalance]		= CONTRACTS_AND_GRANTS_BEGIN_BAL
      ,[JulyTransactionsTotalAmount]			= JUL_TRANS_TOTAL_AMT
      ,[AugustTransactionsTotalAmount]			= AUG_TRANS_TOTAL_AMT
      ,[SeptemberTransactionsTotalAmount]		= SEP_TRANS_TOTAL_AMT
      ,[OctoberTransactionsTotalAmount]			= OCT_TRANS_TOTAL_AMT
      ,[NovemberTransactionsTotalAmount]		= NOV_TRANS_TOTAL_AMT
      ,[DecemberTransactionsTotalAmount]		= DEC_TRANS_TOTAL_AMT
      ,[JanuaryTransactionsTotalAmount]			= JAN_TRANS_TOTAL_AMT
      ,[FebruaryTransactionsTotalAmount]		= FEB_TRANS_TOTAL_AMT
      ,[MarchTransactionsTotalAmount]			= MAR_TRANS_TOTAL_AMT
      ,[AprilTransactionsTotalAmount]			= APR_TRANS_TOTAL_AMT
      ,[MayTransactionsTotalAmount]				= MAY_TRANS_TOTAL_AMT
      ,[JuneTransactionsTotalAmount]			= JUN_TRANS_TOTAL_AMT
      ,[Month13TransactionsTotalAmount]			= MONTH13_TRANS_TOTAL_AMT
      ,[LastUpdateDate]							= LAST_UPDATE_DATE
      
 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	 FISCAL_YEAR
	,CHART_NUM	
	,ORG_ID	
	,ACCT_TYPE_CODE	
	,ACCT_NUM	
	,SUB_ACCT_NUM
	,OBJ_CONSOLIDATN_NUM			
	,OBJECT_NUM	
	,SUB_OBJECT_NUM	
	,PROJECT_NUM
	,BALANCE_TYPE_CODE
	,BALANCE_TYPE_NAME
	,OBJECT_TYPE_CODE
	,SUB_FUND_GROUP_TYPE_CODE
	,BALANCE_CREATE_DATE
	,YTD_ACTUAL_AMT	
	,FISCAL_YEAR_BEGIN_BAL	
	,CONTRACTS_AND_GRANTS_BEGIN_BAL
	,JUL_TRANS_TOTAL_AMT
	,AUG_TRANS_TOTAL_AMT
	,SEP_TRANS_TOTAL_AMT
	,OCT_TRANS_TOTAL_AMT
	,NOV_TRANS_TOTAL_AMT
	,DEC_TRANS_TOTAL_AMT
	,JAN_TRANS_TOTAL_AMT
	,FEB_TRANS_TOTAL_AMT
	,MAR_TRANS_TOTAL_AMT
	,APR_TRANS_TOTAL_AMT
	,MAY_TRANS_TOTAL_AMT
	,JUN_TRANS_TOTAL_AMT
	,MONTH13_TRANS_TOTAL_AMT
	,LAST_UPDATE_DATE
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
