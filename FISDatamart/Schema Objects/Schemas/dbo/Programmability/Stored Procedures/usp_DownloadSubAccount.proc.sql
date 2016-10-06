/*
Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110203 by kjt:
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	2011-02-03 by kjt:
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-02-25 by kjt:
		Modified where clause and replaced with inner joins.
	2011-02-28 by kjt:
		Revised from multi IN to INNER JOIN.
		Removed ORDER BY.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to SubAccounts.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE Procedure [dbo].[usp_DownloadSubAccount]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.SubAccount.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in SubAccount table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.SubAccount.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'SubAccounts', --Can be passed another table name, i.e. #SubAccounts, etc.
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
	--DECLARE @TableName varchar(255) = 'SubAccounts' --Name of table being updated.
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
DECLARE @FiscalYearClause varchar(50) = ''
SELECT @FiscalYearClause = 
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
'>= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
'= ' + Convert(char(4), @BeginningFiscalYear)
END

SELECT @WhereClause = '(
						SA.FISCAL_YEAR ' +
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
						AND SA.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
							AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd'''')'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')' END
END

SELECT @WhereClause += '
					)'
-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading SubAccounts records...'
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
merge SubAccounts as SubAccounts
	using
	(
		SELECT 
			Fiscal_Year,
			Fiscal_Period,
			Chart_Num,
			Account_Num,
			SubAccount_Num,
			SubAccount_Name,
			Active_Ind,
			Last_Update_Date,
			Sub_Account_PK
		FROM
			OPENQUERY (
				FIS_DS,
				''SELECT  
					SA.FISCAL_YEAR			Fiscal_Year,
					SA.FISCAL_PERIOD		Fiscal_Period,
					SA.CHART_NUM			Chart_Num, 
					SA.ACCT_NUM				Account_Num, 
					SA.SUB_ACCT_NUM			SubAccount_Num, 
					SA.SUB_ACCT_NAME		SubAccount_Name, 
					SA.SUB_ACCT_ACTIVE_IND	Active_Ind,
					SA.DS_LAST_UPDATE_DATE	Last_Update_Date,
					SA.FISCAL_YEAR || ''''|'''' || SA.FISCAL_PERIOD || ''''|'''' || SA.CHART_NUM || ''''|'''' || SA.ACCT_NUM  || ''''|'''' || SA.SUB_ACCT_NUM as Sub_Account_PK
				FROM 
					FINANCE.SUB_ACCOUNT SA
					INNER JOIN 
					(
						SELECT DISTINCT CHART_NUM, ACCT_NUM
						FROM FINANCE.ORGANIZATION_ACCOUNT
						WHERE 
							(
								(
									FISCAL_YEAR ' + @FiscalYearClause + '
								)
								AND 
								(CHART_NUM, ORG_ID) IN 
								(	
									SELECT DISTINCT CHART_NUM, ORG_ID 
									FROM FINANCE.ORGANIZATION_HIERARCHY Org 
									WHERE
										FISCAL_YEAR ' + @FiscalYearClause + ' 
										AND
										(
											(CHART_NUM_LEVEL_1 = ''''3'''' AND ORG_ID_LEVEL_1 = ''''AAES'''')
											OR
											(CHART_NUM_LEVEL_2 = ''''L'''' AND ORG_ID_LEVEL_2 = ''''AAES'''')
									
											OR
											(ORG_ID_LEVEL_1 = ''''BIOS'''')
							
											OR 
											(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4 = ''''AAES'''')
											OR
											(CHART_NUM_LEVEL_5 = ''''L'''' AND ORG_ID_LEVEL_5 = ''''AAES'''')
											
											OR
											(ORG_ID_LEVEL_4 = ''''BIOS'''')
										)
								)
							)
					) A ON SA.CHART_NUM = A.CHART_NUM AND SA.ACCT_NUM = A.ACCT_NUM
				WHERE 
					' + @WhereClause + '
				--ORDER BY SA.FISCAL_YEAR, SA.FISCAL_PERIOD, SA.CHART_NUM, SA.ACCT_NUM, SA.SUB_ACCT_NUM
		'')
	) FIS_DS_SUB_ACCOUNT ON SubAccounts.SubAccountPK = FIS_DS_SUB_ACCOUNT.Sub_Account_PK

	WHEN MATCHED THEN UPDATE set
	   [SubAccountName] = SubAccount_Name
      ,[ActiveInd] = Active_Ind
      ,[LastUpdateDate] = Last_Update_Date

	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
		(Fiscal_Year,
		Fiscal_Period,
		Chart_Num,
		Account_Num,
		SubAccount_Num,
		SubAccount_Name,
		Active_Ind,
		Last_Update_Date,
		Sub_Account_PK
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
