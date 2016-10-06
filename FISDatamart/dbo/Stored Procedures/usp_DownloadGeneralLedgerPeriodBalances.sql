/*
Modifications:
	20110203 by kjt:
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	20110216 by kjt:
		Fixed a typo in the where clause generation logic.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE Procedure [dbo].[usp_DownloadGeneralLedgerPeriodBalances]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.GENERAL_LEDGER_PERIOD_BALANCES.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in GeneralLedgerPeriodBalances table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.GENERAL_LEDGER_PERIOD_BALANCES.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'GeneralLedgerPeriodBalances', --Can be passed another table name, i.e. #GeneralLedgerPeriodBalances, etc.
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
	--DECLARE @TableName varchar(255) = 'GeneralLedgerPeriodBalances' --Name of table being updated.
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
SELECT @WhereClause = 
'	GL_PeriodBals.FISCAL_YEAR ' +
CASE WHEN (@BeginningFiscalYear <> @EndingFiscalYear) THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
ELSE
'= ' + Convert(char(4), @BeginningFiscalYear)
END 												            
	+	' AND GL_PeriodBals.Fiscal_Period = ''''--''''
	        	AND
				(
					(
						(Orgs.CHART_NUM_LEVEL_1 = ''''3'''' and Orgs.ORG_ID_LEVEL_1 = ''''AAES'''')
						OR
						(Orgs.CHART_NUM_LEVEL_2 = ''''L'''' and Orgs.ORG_ID_LEVEL_2 = ''''AAES'''')
						OR 
						(Orgs.CHART_NUM_LEVEL_4 IN (''''3'''',  ''''L'''') AND Orgs.ORG_ID_LEVEL_4 = ''''AAES'''')
						OR
						(Orgs.CHART_NUM_LEVEL_5 = ''''L'''' AND Orgs.ORG_ID_LEVEL_5 = ''''AAES'''')
					)
				)'

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
	        	AND (GL_PeriodBals.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
					AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading GeneralLedgerPeriodBalances records...'
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
merge ' + @TableName + ' as GeneralLedgerPeriodBalances
using
(
SELECT
     PK_GL_PERIOD_BALANCES
	,FISCAL_YEAR
	,FISCAL_PERIOD	
	,CHART_NUM	
	,ORG_ID	
	,ACCT_TYPE_CODE	
	,ACCT_NUM	
	,SUB_ACCT_NUM	
	,OBJ_CONSOLIDATN_NUM	
	,OBJECT_TYPE_CODE	
	,OBJECT_NUM	
	,SUB_OBJECT_NUM	
	,BALANCE_TYPE_CODE	
	,BALANCE_TYPE_NAME	
	,SUB_FUND_GROUP_TYPE_CODE	
	,FISCAL_YEAR_FIN_BEGIN_BAL	
	,FISCAL_YEAR_CG_BEGIN_BAL	
	,FISCAL_PERIOD_BEGIN_BAL	
	,FISCAL_PERIOD_TRANS_TOTAL_AMT	
	,DS_LAST_UPDATE_DATE  AS LAST_UPDATE_DATE
FROM OPENQUERY (FIS_DS, 
			''SELECT (GL_PeriodBals.FISCAL_YEAR || GL_PeriodBals.FISCAL_PERIOD || GL_PeriodBals.CHART_NUM || GL_PeriodBals.ACCT_NUM || GL_PeriodBals.SUB_ACCT_NUM || GL_PeriodBals.OBJECT_TYPE_CODE || GL_PeriodBals. OBJECT_NUM || GL_PeriodBals.SUB_OBJECT_NUM || GL_PeriodBals.BALANCE_TYPE_CODE) AS PK_GL_PERIOD_BALANCES,
			GL_PeriodBals.FISCAL_YEAR,
			GL_PeriodBals.FISCAL_PERIOD,
			GL_PeriodBals.CHART_NUM,
			GL_PeriodBals.ORG_ID,
			GL_PeriodBals.ACCT_TYPE_CODE,
			GL_PeriodBals.ACCT_NUM,
			GL_PeriodBals.SUB_ACCT_NUM,
			GL_PeriodBals.OBJ_CONSOLIDATN_NUM,
			GL_PeriodBals.OBJECT_TYPE_CODE,
			GL_PeriodBals.OBJECT_NUM,
			GL_PeriodBals.SUB_OBJECT_NUM,
			GL_PeriodBals.BALANCE_TYPE_CODE,
			GL_PeriodBals.BALANCE_TYPE_NAME,
			GL_PeriodBals.SUB_FUND_GROUP_TYPE_CODE,
			GL_PeriodBals.FISCAL_YEAR_FIN_BEGIN_BAL,
			GL_PeriodBals.FISCAL_YEAR_CG_BEGIN_BAL,
			GL_PeriodBals.FISCAL_PERIOD_BEGIN_BAL,
			GL_PeriodBals.FISCAL_PERIOD_TRANS_TOTAL_AMT,
			GL_PeriodBals.DS_LAST_UPDATE_DATE
			from FINANCE.general_ledger_period_balances GL_PeriodBals
			INNER JOIN FINANCE.organization_hierarchy Orgs ON 
				GL_PeriodBals.Org_ID = Orgs.Org_ID 
				AND GL_PeriodBals.Fiscal_Year = Orgs.Fiscal_Year 
				AND GL_PeriodBals.Fiscal_Period = Orgs.Fiscal_Period 
				AND GL_PeriodBals.Chart_Num = Orgs.Chart_Num
			WHERE 
			' + @WhereClause + '
		'')
) FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES on PK_GL_PERIOD_BALANCES = (Convert(char(4), Year) + Period +
Chart + Account + SubAccount + ObjectType + Object + SubObject + BalType)
/*
GeneralLedgerPeriodBalances.AccountPK = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.FISCAL_YEAR
AND GeneralLedgerPeriodBalances.Period = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.FISCAL_PERIOD
AND GeneralLedgerPeriodBalances.Chart = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.CHART_NUM
AND GeneralLedgerPeriodBalances.Account = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.ACCT_NUM
AND GeneralLedgerPeriodBalances.SubAccount = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.SUB_ACCT_NUM
AND GeneralLedgerPeriodBalances.Object = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.OBJECT_NUM
AND GeneralLedgerPeriodBalances.SubObject = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.SUB_OBJECT_NUM
AND GeneralLedgerPeriodBalances.BalType = FIS_DS_GENERAL_LEDGER_PERIOD_BALANCES.BALANCE_TYPE_CODE
*/

WHEN MATCHED THEN UPDATE set
	   [OrgID]									= ORG_ID
      ,[AccountType]							= ACCT_TYPE_CODE
      ,[ObjectConsolidatnNum]					= OBJ_CONSOLIDATN_NUM
      ,[YearFinancialBeginningBalance]			= FISCAL_YEAR_FIN_BEGIN_BAL
      ,[YearContractsAndGrantsBeginningBalance] = FISCAL_YEAR_CG_BEGIN_BAL
      ,[PeriodBeginningBalance]					= FISCAL_PERIOD_BEGIN_BAL
      ,[PeriodTransactionsTotal]				= FISCAL_PERIOD_TRANS_TOTAL_AMT
      ,[LastUpdateDate]							= LAST_UPDATE_DATE
      
 WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
 (
	 FISCAL_YEAR
	,FISCAL_PERIOD	
	,CHART_NUM	
	,ACCT_NUM	
	,SUB_ACCT_NUM
	,OBJECT_TYPE_CODE			
	,OBJECT_NUM	
	,SUB_OBJECT_NUM	
	,BALANCE_TYPE_CODE	
	,ORG_ID	
	,ACCT_TYPE_CODE	
	,OBJ_CONSOLIDATN_NUM	
	,FISCAL_PERIOD_BEGIN_BAL	
	,FISCAL_PERIOD_TRANS_TOTAL_AMT
	,BALANCE_TYPE_NAME	
	,SUB_FUND_GROUP_TYPE_CODE	
	,FISCAL_YEAR_FIN_BEGIN_BAL	
	,FISCAL_YEAR_CG_BEGIN_BAL	
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