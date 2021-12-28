
CREATE PROCEDURE [dbo].[Step4]
AS
BEGIN
merge Objects as Objects
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
		'
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
			O.FISCAL_YEAR || ''|'' || O.CHART_NUM || ''|'' || O.OBJECT_NUM as Object_PK
		FROM 
			FINANCE.OBJECT O 
		WHERE 
			(
			 	O.FISCAL_YEAR >= 2011
				AND O.CHART_NUM IN (''3'',''L'')
			)
		ORDER BY O.chart_num, O.object_num
		')
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
;
END