/*
Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	2011-02-02 by kjt: 
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	2011-02-03 by kjt:
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-03-02 by kjt:
		Changed erroneous table name from Objects to Projects.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to Projects.
	2015-10-08 by kjt: Modifications to take into account removing DANR as level 4 ORG for chart L, and moving
		AANS up to level 4 org position.  AAES is now at Level 4 for both Chart 'L' and Chart '3' as of FY 2016.
*/
CREATE Procedure [dbo].[usp_DownloadProjects]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.PROJECT.LAST_UPDATE_DATE) 
		--optional, defaults to highest date in Projects table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.PROJECT.LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'Projects', --Can be passed another table name, i.e. #Projects, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
)
AS

--local:
DECLARE @TSQL varchar(MAX)= ''--Holds T-SQL code to be run with EXEC() function.
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
	--DECLARE @TableName varchar(255) = 'Projects' --Name of table being updated.
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
'P.FISCAL_YEAR ' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
'BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
'>= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
'= ' + Convert(char(4), @BeginningFiscalYear)
END 

SELECT @WhereClause += '
					AND 
						(CHART_NUM, ORG_ID) IN 
						(
							SELECT DISTINCT CHART_NUM, ORG_ID 
							FROM FINANCE.ORGANIZATION_HIERARCHY O
							WHERE
							(
								(CHART_NUM_LEVEL_1=''''3'''' AND ORG_ID_LEVEL_1 = ''''AAES'''')
								OR
								(CHART_NUM_LEVEL_2=''''L'''' AND ORG_ID_LEVEL_2 = ''''AAES'''')
								
								OR 
								(ORG_ID_LEVEL_1 = ''''BIOS'''')
								
								OR 
								(CHART_NUM_LEVEL_4 IN (''''3'''', ''''L'''') AND ORG_ID_LEVEL_4 = ''''AAES'''')
								OR
								(CHART_NUM_LEVEL_5=''''L'''' AND ORG_ID_LEVEL_5 = ''''AAES'''')
								
								OR
								(ORG_ID_LEVEL_4 = ''''BIOS'''')
							)
							AND
							(
								FISCAL_YEAR' +
								CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND @EndingFiscalYear <> 9999 THEN
								' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
								' AND ' + + Convert(char(4), @EndingFiscalYear)
									WHEN @EndingFiscalYear = 9999 THEN
									' >= ' + Convert(char(4), @BeginningFiscalYear)
								ELSE 
									' = ' + Convert(char(4), @BeginningFiscalYear)
								END + '	
							)
						)'												            

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
					AND P.LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
						AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd'''')'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading Projects records...'
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
merge ' + @TableName + ' as Projects 
	using
	(
		SELECT
			Fiscal_Year,
			Fiscal_Period,
			Project_Num,
			Project_Name,
			Project_Manager_ID,
			Chart_Num,
			Org_ID,
			Project_Active_Ind,
			Project_Description,
			Last_Update_Date,
			Projects_PK
	
		FROM
			OPENQUERY (
				FIS_DS,
				''SELECT 
					P.FISCAL_YEAR			Fiscal_Year,
					P.FISCAL_PERIOD			Fiscal_Period,
					P.PROJECT_NUM			Project_Num, 
					P.PROJECT_NAME			Project_Name, 
					P.PROJECT_MGR_ID		Project_Manager_ID, 
					P.CHART_NUM				Chart_Num, 
					P.ORG_ID				Org_ID, 
					P.PROJECT_ACTIVE_CODE	Project_Active_Ind, 
					P.PROJECT_DESC			Project_Description,
					P.LAST_UPDATE_DATE		Last_Update_Date,
					P.FISCAL_YEAR || ''''|'''' || P.FISCAL_PERIOD || ''''|'''' || P.CHART_NUM || ''''|'''' || P.PROJECT_NUM	as Projects_PK
				FROM
					FINANCE.PROJECTS P
				WHERE 
					' + @WhereClause + '
				ORDER BY
					P.FISCAL_YEAR, P.FISCAL_PERIOD, P.PROJECT_NUM
			'')
	) FIS_DS_PROJECTS on Projects.ProjectsPK = FIS_DS_PROJECTS.Projects_PK

	WHEN MATCHED THEN UPDATE set
       [Name] = Project_Name
      ,[ManagerID] = Project_Manager_ID
      ,[Chart] = Chart_Num
      ,[OrgID] = Org_ID
      ,[ActiveInd] = Project_Active_Ind
      ,[Description] = Project_Description
      ,[LastUpdateDate] = Last_Update_Date
      
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
		(Fiscal_Year,
		Fiscal_Period,
		Project_Num ,
		Project_Name,
		Project_Manager_ID,
		Chart_Num,
		Org_ID,
		Project_Active_Ind,
		Project_Description,
		Last_Update_Date,
		Projects_PK)
	
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
