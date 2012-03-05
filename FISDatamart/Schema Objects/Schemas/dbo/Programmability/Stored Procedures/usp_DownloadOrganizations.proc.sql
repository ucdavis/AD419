/*
Modifications:
	20110128 by kjt:
		Analyzed the org level and chart mapping and found that it need to be revised
		because a few of the chart L BIOS orgs were being excluded.
	20110202 by kjt:
		Replaced date logic with call to udf_GetBeginningAndLastFiscalYearToDownload.
	2011-02-03 by kjt:
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to Organizations.
*/
CREATE Procedure [dbo].[usp_DownloadOrganizations]
(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.ORGANIZATION_HIERARCHY.ORG_UPDATE_DATE) 
		--optional, defaults to highest date in Objects table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.ORGANIZATION_HIERARCHY.ORG_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'Organizations', --Can be passed another table name, i.e. #Organizations, etc.
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
--DECLARE @TableName varchar(255) = 'Organizations' --Name of table being updated.
DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
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
'Orgs.FISCAL_YEAR' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          @EndingFiscalYear <> 9999 THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN @EndingFiscalYear = 9999 THEN
' >= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
' = ' + Convert(char(4), @BeginningFiscalYear)
END 

SELECT @WhereClause += '
					AND 
					(
						(CHART_NUM_LEVEL_1=''''3'''' AND ORG_ID_LEVEL_1 = ''''AAES'''')
						OR
						(CHART_NUM_LEVEL_2=''''L'''' AND ORG_ID_LEVEL_2 = ''''AAES'''')
						
						OR
						(ORG_ID_LEVEL_1 = ''''BIOS'''')
						
						OR 
						(CHART_NUM_LEVEL_4 = ''''3'''' AND ORG_ID_LEVEL_4 = ''''AAES'''')
						OR
						(CHART_NUM_LEVEL_5 = ''''L'''' AND ORG_ID_LEVEL_5 = ''''AAES'''')
						
						OR
						(ORG_ID_LEVEL_4 = ''''BIOS'''')
						
						
					)'

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
					AND (Orgs.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
						AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading Organizations records...'
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
merge ' + @TableName + ' AS Organizations
	using
	(
		SELECT  
			Year, Period, Org, Chart,Org_Level as Level,Org_Name as Name,
			Org_Type Type,  Begin_Date as BeginDate,End_Date as EndDate,
			Home_Dept_Num as HomeDeptNum,Home_Dept_Name as HomeDeptName,
			Update_Date as UpdateDate,
			Chart_1 as Chart1,Org_1 as Org1,Name_1 as Name1,
			Chart_2 as Chart2,Org_2 as Org2,Name_2 as Name2,
			Chart_3 as Chart3,Org_3 as Org3,Name_3 as Name3,
			Chart_4 as Chart4,Org_4 as Org4,Name_4 as Name4,
			Chart_5 as Chart5,Org_5 as Org5,Name_5 as Name5,
			Chart_6 as Chart6,Org_6 as Org6,Name_6 as Name6,
			Chart_7 as Chart7,Org_7 as Org7,Name_7 as Name7,
			Chart_8 as Chart8,Org_8 as Org8,Name_8 as Name8,
			Chart_9 as Chart9,Org_9 as Org9,Name_9 as Name9,
			Chart_10 as Chart10,Org_10 as Org10,Name_10 as Name10,
			Chart_11 as Chart11,Org_11 as Org11,Name_11 as Name11,
			Chart_12 as Chart12,Org_12 as Org12,Name_12 as Name12,
			Active_Ind as ActiveInd,
			Organization_PK as OrganizationPK,
			Last_Update_Date as LastUpdateDate
		FROM
			OPENQUERY (
				FIS_DS,
				''SELECT 
					FISCAL_YEAR Year,
					FISCAL_PERIOD Period,
					CHART_NUM Chart,
					ORG_ID Org,
					ORG_HIERARCHY_LEVEL Org_Level,
					ORG_NAME Org_Name,
					ORG_TYPE_CODE Org_Type,
					TO_CHAR(ORG_BEGIN_DATE) Begin_Date,
					TO_CHAR(ORG_END_DATE) End_Date,
					HOME_DEPARTMENT_NUM Home_Dept_Num,
					HOME_DEPARTMENT_PRIMARY_NAME Home_Dept_Name,
					TO_CHAR(ORG_UPDATE_DATE) Update_Date,
					CHART_NUM_LEVEL_1 Chart_1,
					ORG_ID_LEVEL_1 Org_1,
					ORG_NAME_LEVEL_1 Name_1,
					CHART_NUM_LEVEL_2 Chart_2,
					ORG_ID_LEVEL_2 Org_2,
					ORG_NAME_LEVEL_2 Name_2,
					CHART_NUM_LEVEL_3 Chart_3,
					ORG_ID_LEVEL_3 Org_3,
					ORG_NAME_LEVEL_3 Name_3,
					CHART_NUM_LEVEL_4 Chart_4,
					ORG_ID_LEVEL_4 Org_4,
					ORG_NAME_LEVEL_4 Name_4,
					CHART_NUM_LEVEL_5 Chart_5,
					ORG_ID_LEVEL_5 Org_5,
					ORG_NAME_LEVEL_5 Name_5,
					CHART_NUM_LEVEL_6 Chart_6,
					ORG_ID_LEVEL_6 Org_6,
					ORG_NAME_LEVEL_6 Name_6,
					CHART_NUM_LEVEL_7 Chart_7,
					ORG_ID_LEVEL_7 Org_7,
					ORG_NAME_LEVEL_7 Name_7,
					CHART_NUM_LEVEL_8 Chart_8,
					ORG_ID_LEVEL_8 Org_8,
					ORG_NAME_LEVEL_8 Name_8,
					CHART_NUM_LEVEL_9 Chart_9,
					ORG_ID_LEVEL_9 Org_9,
					ORG_NAME_LEVEL_9 Name_9,
					CHART_NUM_LEVEL_10 Chart_10,
					ORG_ID_LEVEL_10 Org_10,
					ORG_NAME_LEVEL_10 Name_10,
					CHART_NUM_LEVEL_11 Chart_11,
					ORG_ID_LEVEL_11 Org_11,
					ORG_NAME_LEVEL_11 Name_11,
					CHART_NUM_LEVEL_12 Chart_12,
					ORG_ID_LEVEL_12 Org_12,
					ORG_NAME_LEVEL_12 Name_12,
					ACTIVE_IND,
					FISCAL_YEAR || ''''|'''' || FISCAL_PERIOD || ''''|'''' || CHART_NUM  || ''''|'''' || ORG_ID as Organization_PK,
					ds_last_update_date LAST_UPDATE_DATE
				FROM 
					FINANCE.ORGANIZATION_HIERARCHY Orgs 
				WHERE 
					' + @WhereClause + '
			'')
	) FIS_DS_ORGANIZATIONS on Organizations.OrganizationPK = FIS_DS_ORGANIZATIONS.OrganizationPK

	WHEN MATCHED THEN UPDATE set
	   Organizations.Level = FIS_DS_ORGANIZATIONS.Level
	  ,Organizations.Name = FIS_DS_ORGANIZATIONS.Name
      ,Organizations.[Type] = FIS_DS_ORGANIZATIONS.[Type]
      ,Organizations.[BeginDate] = FIS_DS_ORGANIZATIONS.[BeginDate]
      ,Organizations.[EndDate] = FIS_DS_ORGANIZATIONS.[EndDate]
      ,Organizations.[HomeDeptNum] = FIS_DS_ORGANIZATIONS.[HomeDeptNum]
      ,Organizations.[HomeDeptName] = FIS_DS_ORGANIZATIONS.[HomeDeptName]
      ,Organizations.[UpdateDate] = FIS_DS_ORGANIZATIONS.[UpdateDate]
      ,Organizations.[Chart1] = FIS_DS_ORGANIZATIONS.[Chart1]
      ,Organizations.[Org1] = FIS_DS_ORGANIZATIONS.[Org1]
      ,Organizations.[Name1] = FIS_DS_ORGANIZATIONS.[Name1]
      ,Organizations.[Chart2] = FIS_DS_ORGANIZATIONS.[Chart2]
      ,Organizations.[Org2] = FIS_DS_ORGANIZATIONS.[Org2]
      ,Organizations.[Name2] = FIS_DS_ORGANIZATIONS.[Name2]
      ,Organizations.[Chart3] = FIS_DS_ORGANIZATIONS.[Chart3]
      ,Organizations.[Org3] = FIS_DS_ORGANIZATIONS.[Org3]
      ,Organizations.[Name3] = FIS_DS_ORGANIZATIONS.[Name3]
      ,Organizations.[Chart4] = FIS_DS_ORGANIZATIONS.[Chart4]
      ,Organizations.[Org4] = FIS_DS_ORGANIZATIONS.[Org4]
      ,Organizations.[Name4] = FIS_DS_ORGANIZATIONS.[Name4]
      ,Organizations.[Chart5] = FIS_DS_ORGANIZATIONS.[Chart5]
      ,Organizations.[Org5] = FIS_DS_ORGANIZATIONS.[Org5]
      ,Organizations.[Name5] = FIS_DS_ORGANIZATIONS.[Name5]
      ,Organizations.[Chart6] = FIS_DS_ORGANIZATIONS.[Chart6]
      ,Organizations.[Org6] = FIS_DS_ORGANIZATIONS.[Org6]
      ,Organizations.[Name6] = FIS_DS_ORGANIZATIONS.[Name6]
      ,Organizations.[Chart7] = FIS_DS_ORGANIZATIONS.[Chart7]
      ,Organizations.[Org7] = FIS_DS_ORGANIZATIONS.[Org7]
      ,Organizations.[Name7] = FIS_DS_ORGANIZATIONS.[Name7]
      ,Organizations.[Chart8] = FIS_DS_ORGANIZATIONS.[Chart8]
      ,Organizations.[Org8] = FIS_DS_ORGANIZATIONS.[Org8]
      ,Organizations.[Name8] = FIS_DS_ORGANIZATIONS.[Name8]
      ,Organizations.[Chart9] = FIS_DS_ORGANIZATIONS.[Chart9]
      ,Organizations.[Org9] = FIS_DS_ORGANIZATIONS.[Org9]
      ,Organizations.[Name9] = FIS_DS_ORGANIZATIONS.[Name9]
      ,Organizations.[Chart10] = FIS_DS_ORGANIZATIONS.[Chart10]
      ,Organizations.[Org10] = FIS_DS_ORGANIZATIONS.[Org10]
      ,Organizations.[Name10] = FIS_DS_ORGANIZATIONS.[Name10]
      ,Organizations.[Chart11] = FIS_DS_ORGANIZATIONS.[Chart11]
      ,Organizations.[Org11] = FIS_DS_ORGANIZATIONS.[Org11]
      ,Organizations.[Name11] = FIS_DS_ORGANIZATIONS.[Name11]
      ,Organizations.[Chart12] = FIS_DS_ORGANIZATIONS.[Chart12]
      ,Organizations.[Org12] = FIS_DS_ORGANIZATIONS.[Org12]
      ,Organizations.[Name12] = FIS_DS_ORGANIZATIONS.[Name12]
      ,Organizations.[ActiveIndicator] = FIS_DS_ORGANIZATIONS.[ActiveInd]
      ,Organizations.[LastUpdateDate] = FIS_DS_ORGANIZATIONS.[LastUpdateDate]
  
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
      ([Year]
      ,[Period]
      ,[Org]
      ,[Chart]
      ,[Level]
      ,[Name]
      ,[Type]
      ,[BeginDate]
      ,[EndDate]
      ,[HomeDeptNum]
      ,[HomeDeptName]
      ,[UpdateDate]
      ,[Chart1]
      ,[Org1]
      ,[Name1]
      ,[Chart2]
      ,[Org2]
      ,[Name2]
      ,[Chart3]
      ,[Org3]
      ,[Name3]
      ,[Chart4]
      ,[Org4]
      ,[Name4]
      ,[Chart5]
      ,[Org5]
      ,[Name5]
      ,[Chart6]
      ,[Org6]
      ,[Name6]
      ,[Chart7]
      ,[Org7]
      ,[Name7]
      ,[Chart8]
      ,[Org8]
      ,[Name8]
      ,[Chart9]
      ,[Org9]
      ,[Name9]
      ,[Chart10]
      ,[Org10]
      ,[Name10]
      ,[Chart11]
      ,[Org11]
      ,[Name11]
      ,[Chart12]
      ,[Org12]
      ,[Name12]
      ,[ActiveInd]
      ,[OrganizationPK]
      ,[LastUpdateDate]
      )
--	WHEN NOT MATCHED BY SOURCE THEN DELETE
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
