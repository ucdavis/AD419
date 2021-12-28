/*
Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110203 by kjt:
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
		
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	20110225 by kjt:
		Modified where clause and replaced with INNER JOINs.
	20110228 by kjt:
		Revised from multi IN to INNER JOIN.
		Removed ORDER BY.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to SubObjects.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE PROCEDURE [dbo].[usp_DownloadSubObjects]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.SUB_OBJECT.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in SubAccount table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.SUB_OBJECT.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'SubObjects', --Can be passed another table name, i.e. #SubObjects, etc.
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
	--DECLARE @TableName varchar(255) = 'SubObjects' --Name of table being updated.
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
-- Add the SubObjects FY filter:

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
						(
							SO.FISCAL_YEAR ' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 '	AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
'>= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
'= ' + Convert(char(4), @BeginningFiscalYear)
END
 
-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
							AND SO.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
								AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd'''')'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')' END
END

SELECT @WhereClause += '
						)
					)'

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading SubObjects records...'
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
merge ' + @TableName + ' as SubObjects
	using
	(
		SELECT 
			Fiscal_Year,
			Fiscal_Period,
			Chart_Num,
			Account_Num,
			[Object],
			SubObject,
			SubObject_Name,
			SubObject_Name_Short,
			SubObject_Active_Ind,
			Last_Update_Date,
			Sub_Object_PK
		FROM
			OPENQUERY (
				FIS_DS,
				''SELECT 
					SO.FISCAL_YEAR Fiscal_Year,
					SO.FISCAL_PERIOD Fiscal_Period,
					SO.CHART_NUM Chart_Num,
					SO.ACCT_NUM Account_Num,
					SO.OBJECT_NUM Object,
					SO.SUB_OBJECT_NUM SubObject,
					SO.SUB_OBJECT_NAME SubObject_Name,
					SO.SUB_OBJECT_SHORT_NAME SubObject_Name_Short,
					SO.SUB_OBJECT_ACTIVE_IND SubObject_Active_Ind,
					SO.DS_LAST_UPDATE_DATE Last_Update_Date,
					SO.FISCAL_YEAR || ''''|'''' || SO.FISCAL_PERIOD || ''''|'''' || SO.CHART_NUM || ''''|'''' || SO.ACCT_NUM || ''''|'''' || SO.OBJECT_NUM  || ''''|'''' || SO.SUB_OBJECT_NUM as Sub_Object_PK
				FROM 
					FINANCE.SUB_OBJECT SO
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
											(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4  = ''''AAES'''')
											OR
											(CHART_NUM_LEVEL_5 = ''''L'''' AND ORG_ID_LEVEL_5 = ''''AAES'''')
											
											OR
											(ORG_ID_LEVEL_4 = ''''BIOS'''')
										)
								)
							)
					
					) ACCT ON SO.CHART_NUM = ACCT.CHART_NUM AND SO.ACCT_NUM = ACCT.ACCT_NUM
					
				WHERE 
					' + @WhereClause + '
	'')
	) FIS_DS_SUB_OBJECT ON SubObjects.SubObjectPK = FIS_DS_SUB_OBJECT.Sub_Object_PK

	WHEN MATCHED THEN UPDATE set
	   [Name] = SubObject_Name
      ,[ShortName] = SubObject_Name_Short
      ,[ActiveInd] = SubObject_Active_Ind
      ,[LastUpdateDate] = Last_Update_Date
	
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
	(
		Fiscal_Year,
		Fiscal_Period,
		Chart_Num,
		Account_Num,
		Object,
		SubObject,
		SubObject_Name,
		SubObject_Name_Short,
		SubObject_Active_Ind,
		Last_Update_Date,
		Sub_Object_PK
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
