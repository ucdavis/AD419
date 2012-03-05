/*
Modifications:
	2011-02-01 by kjt: 
		Removed all date logic and replaced with call to udf_GetBeginningAndLastFiscalYearToDownload instead.
	2011-02-03 by kjt:
		Added variable and modified to pass an argument to udf_GetBeginningAndLastFiscalYearToDownload for 
		@Exclude9999FiscalYear.
	2011-03-04 by kjt:
		Added logic to pass a destination table name; otherwise defaults to Objects.
*/
CREATE Procedure [dbo].[usp_DownloadObjects]

(
	@FirstDateString varchar(16) = null,
		--earliest date to download (FINANCE.OBJECT.DS_LAST_UPDATE_DATE) 
		--optional, defaults to highest date in Objects table
	@LastDateString varchar(16) = null,
		-- latest date to download (FINANCE.OBJECT.DS_LAST_UPDATE_DATE) 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- Flag to determine whether to get just updated records only as opposed all
		-- records for the corresponding Fiscal Years(s).
		-- optional, defaults to getting just the updated records.
	@TableName varchar(255) = 'Objects', --Can be passed another table name, i.e. #Objects, etc.
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
--local:
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	DECLARE @NumFiscalYearsToDownload smallint = null
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'Objects' --Name of table being updated.
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
'	O.FISCAL_YEAR ' +
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
				AND O.CHART_NUM IN (''''3'''',''''L'''')'												            

-- Add the LastUpdateDate portion if appropriate: 
IF @RecordCount > 0 AND @GetUpdatesOnly = 1
BEGIN
	SELECT @WhereClause += '
				AND (O.DS_LAST_UPDATE_DATE ' + 
				CASE WHEN @FirstDate <> @LastDate THEN 'BETWEEN TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd'''')
					AND TO_DATE(''''' + Convert(varchar(10),@LastDate,102)  + ''''' ,''''yyyy.mm.dd''''))'
				ELSE '= TO_DATE(''''' + Convert(varchar(10),@FirstDate,102)  + ''''' ,''''yyyy.mm.dd''''))' END
END

-------------------------------------------------------------------------------------
-- Display the values the sproc will actually run with:
	print '--Downloading Objects records...'
	print '--Table ' + CASE WHEN @RecordCount = 0 THEN 'is EMPTY' ELSE 'has data' END
	print '--Earliest Date = ' + convert(varchar(30),convert(smalldatetime,@FirstDate),102)
	print '--Latest Date = ' + convert(varchar(30),convert(smalldatetime,@LastDate),102)
	print '--Fiscal Year' + CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
ELSE
' = ' + Convert(char(4), @BeginningFiscalYear)
END 												      
	print '--IsDebug = ' + CASE @IsDebug WHEN 1 THEN 'True' ELSE 'False' END
	
-------------------------------------------------------------------------------------
select @TSQL = 
	'
merge ' + @TableName + ' as Objects
using
(
SELECT 
	Fiscal_Year,
	Chart_Num,                     
	Object_Num,
	Object_Name,
	Object_Name_Short,         
	Budget_Aggregation_Code,   
	Object_Type_Code,          
	Object_Sub_Type_Code,      
	Object_Active_Ind,         
	Reports_To_OP_Chart_num,   
	Reports_To_OP_Object_Num,  
	Object_Level_Code,          
	Object_Level_Active_Ind,   
	Obj_Consolidatn_Code,       
	Ref_Cols,
	Object_Type_Name,          
	Object_Sub_Type_Name,      
	Object_Level_Name,         
	Object_Level_Name_Short,   
	Obj_Consolidatn_Name,      
	Obj_Consolidatn_Name_Short,
	Obj_Consolidatn_Active_Ind,
	Last_Update_Date,
	Object_PK
FROM
	OPENQUERY 
		(FIS_DS,
		''
		SELECT 
		    O.FISCAL_YEAR					Fiscal_Year,
			O.CHART_NUM						Chart_Num,                     
			O.OBJECT_NUM					Object_Num,               
			O.OBJECT_NAME					Object_Name,               
			O.OBJECT_SHORT_NAME				Object_Name_Short,         
			O.BUDGET_AGGREGATION_NAME		Budget_Aggregation_Code,   
			O.OBJECT_TYPE_CODE				Object_Type_Code,          
			O.Object_sub_type_code			Object_Sub_Type_Code,      
			O.Object_active_code			Object_Active_Ind,         
			O.Op_reports_to_chart_num		Reports_To_OP_Chart_num,   
			O.Op_reports_to_object_num		Reports_To_OP_Object_Num,  
			O.Object_level_num				Object_Level_Code,          
			O.Object_level_active_code		Object_Level_Active_Ind,   
			O.Obj_consolidatn_num			Obj_Consolidatn_Code,       
			0                               Ref_Cols,
			O.Object_type_name				Object_Type_Name,          
			O.Object_sub_type_name			Object_Sub_Type_Name,      
			O.Object_level_name				Object_Level_Name,         
			O.Object_level_short_name		Object_Level_Name_Short,   
			O.Obj_consolidatn_name			Obj_Consolidatn_Name,      
			O.Obj_consolidatn_short_name	Obj_Consolidatn_Name_Short,
			O.Obj_consolidatn_active_code	Obj_Consolidatn_Active_Ind,
			O.DS_LAST_UPDATE_DATE			Last_Update_Date,
			O.FISCAL_YEAR || ''''|'''' || O.CHART_NUM || ''''|'''' || O.OBJECT_NUM as Object_PK
		FROM 
			FINANCE.OBJECT O 
		WHERE 
			(
			 ' + @WhereClause + '
			)
		ORDER BY O.chart_num, O.object_num
		'')
) FIS_DS_OBJECTS on Objects.ObjectPK = FIS_DS_OBJECTS.Object_PK

WHEN MATCHED THEN UPDATE set
	   [Name]	=	Object_Name
      ,[ShortName]	=	Object_Name_Short         
      ,[BudgetAggregationCode]	=	Budget_Aggregation_Code   
      ,[TypeCode]	=	Object_Type_Code          
      ,[SubTypeCode]	=	Object_Sub_Type_Code      
      ,[ActiveInd]	=	Object_Active_Ind         
      ,[ReportsToOPChartNum]	=	Reports_To_OP_Chart_num   
      ,[ReportsToOPObjectNum]	=	Reports_To_OP_Object_Num  
      ,[LevelCode]	=	Object_Level_Code          
      ,[LevelActiveInd]	=	Object_Level_Active_Ind   
      ,[ConsolidatnCode]	=	Obj_Consolidatn_Code       
      ,[RefCols]	=	Ref_Cols
      ,[TypeName]	=	Object_Type_Name          
      ,[SubTypeName]	=	Object_Sub_Type_Name      
      ,[LevelName]	=	Object_Level_Name         
      ,[ObjectLevelShortName]	=	Object_Level_Name_Short   
      ,[ConsolidatnName]	=	Obj_Consolidatn_Name      
      ,[ConsolidatnShortName]	=	Obj_Consolidatn_Name_Short
      ,[ConsolidatnActiveInd]	=	Obj_Consolidatn_Active_Ind
      ,[LastUpdateDate]	=	Last_Update_Date
      
WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
(
    Fiscal_Year,
	Chart_Num,                     
	Object_Num,
	Object_Name,
	Object_Name_Short,         
	Budget_Aggregation_Code,   
	Object_Type_Code,          
	Object_Sub_Type_Code,      
	Object_Active_Ind,         
	Reports_To_OP_Chart_num,   
	Reports_To_OP_Object_Num,  
	Object_Level_Code,          
	Object_Level_Active_Ind,   
	Obj_Consolidatn_Code,       
	Ref_Cols,
	Object_Type_Name,          
	Object_Sub_Type_Name,      
	Object_Level_Name,         
	Object_Level_Name_Short,   
	Obj_Consolidatn_Name,      
	Obj_Consolidatn_Name_Short,
	Obj_Consolidatn_Active_Ind,
	Last_Update_Date,
	Object_PK
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
