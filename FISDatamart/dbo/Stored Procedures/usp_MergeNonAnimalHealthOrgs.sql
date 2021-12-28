

-- =============================================
-- Author:		Ken Taylor
-- Create date: December 13, 2019
-- Description:	Merges the Organizations table with orgs outside of AAES, BIOS, and VETM,
-- which are present in campus' CS_TRACKING_ACTIVE table, so we can use it for figuring out
-- the Scientist Years and Cost Share Scientist Years.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeNonAnimalHealthOrgs]
		@FiscalYear = 2018,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeNonAnimalHealthOrgs]
	@FiscalYear int = 2018, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
merge Organizations AS Orgs
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
				''SELECT DISTINCT
					oh.FISCAL_YEAR Year,
					oh.FISCAL_PERIOD Period,
					oh.CHART_NUM Chart,
					oh.ORG_ID Org,
					oh.ORG_HIERARCHY_LEVEL Org_Level,
					oh.ORG_NAME Org_Name,
					oh.ORG_TYPE_CODE Org_Type,
					TO_CHAR(oh.ORG_BEGIN_DATE) Begin_Date,
					TO_CHAR(oh.ORG_END_DATE) End_Date,
					oh.HOME_DEPARTMENT_NUM Home_Dept_Num,
					oh.HOME_DEPARTMENT_PRIMARY_NAME Home_Dept_Name,
					TO_CHAR(oh.ORG_UPDATE_DATE) Update_Date,
					oh.CHART_NUM_LEVEL_1 Chart_1,
					oh.ORG_ID_LEVEL_1 Org_1,
					oh.ORG_NAME_LEVEL_1 Name_1,
					oh.CHART_NUM_LEVEL_2 Chart_2,
					oh.ORG_ID_LEVEL_2 Org_2,
					oh.ORG_NAME_LEVEL_2 Name_2,
					oh.CHART_NUM_LEVEL_3 Chart_3,
					oh.ORG_ID_LEVEL_3 Org_3,
					oh.ORG_NAME_LEVEL_3 Name_3,
					oh.CHART_NUM_LEVEL_4 Chart_4,
					oh.ORG_ID_LEVEL_4 Org_4,
					oh.ORG_NAME_LEVEL_4 Name_4,
					oh.CHART_NUM_LEVEL_5 Chart_5,
					oh.ORG_ID_LEVEL_5 Org_5,
					oh.ORG_NAME_LEVEL_5 Name_5,
					oh.CHART_NUM_LEVEL_6 Chart_6,
					oh.ORG_ID_LEVEL_6 Org_6,
					oh.ORG_NAME_LEVEL_6 Name_6,
					oh.CHART_NUM_LEVEL_7 Chart_7,
					oh.ORG_ID_LEVEL_7 Org_7,
					oh.ORG_NAME_LEVEL_7 Name_7,
					oh.CHART_NUM_LEVEL_8 Chart_8,
					oh.ORG_ID_LEVEL_8 Org_8,
					oh.ORG_NAME_LEVEL_8 Name_8,
					oh.CHART_NUM_LEVEL_9 Chart_9,
					oh.ORG_ID_LEVEL_9 Org_9,
					oh.ORG_NAME_LEVEL_9 Name_9,
					oh.CHART_NUM_LEVEL_10 Chart_10,
					oh.ORG_ID_LEVEL_10 Org_10,
					oh.ORG_NAME_LEVEL_10 Name_10,
					oh.CHART_NUM_LEVEL_11 Chart_11,
					oh.ORG_ID_LEVEL_11 Org_11,
					oh.ORG_NAME_LEVEL_11 Name_11,
					oh.CHART_NUM_LEVEL_12 Chart_12,
					oh.ORG_ID_LEVEL_12 Org_12,
					oh.ORG_NAME_LEVEL_12 Name_12,
					oh.ACTIVE_IND,
					oh.FISCAL_YEAR || ''''|'''' || oh.FISCAL_PERIOD || ''''|'''' || oh.CHART_NUM  || ''''|'''' || oh.ORG_ID as Organization_PK,
					oh.ds_last_update_date LAST_UPDATE_DATE
				FROM
	FINANCE.CS_TRACKING_ENTRY_ACTIVE te
INNER JOIN FINANCE.ORGANIZATION_ACCOUNT oa ON 
    oa.CHART_NUM = te.CHART_NUM AND oa.ACCT_NUM = te.ACCT_NUM and 
    oa.FISCAL_YEAR = 9999 and oa.FISCAL_PERIOD = ''''--''''
INNER JOIN FINANCE.ORGANIZATION_HIERARCHY oh ON 
    oh.FISCAL_YEAR = 9999 and oh.FISCAL_PERIOD = ''''--'''' AND 
    oh.CHART_NUM = oa.CHART_NUM AND oh.ORG_ID = oa.ORG_ID AND oh.ORG_ID_LEVEL_4 = ''''VETM''''
INNER JOIN Finance.OP_FUND f ON 
    f.OP_LOCATION_CODE = te.OP_LOCATION_CODE AND 
    f.OP_FUND_NUM = te.OP_FUND_NUM AND
    f.FISCAL_YEAR = 9999 AND f.FISCAL_PERIOD = ''''--''''  
    AND f.AWARD_BEGIN_DATE < TO_DATE(''''' + CONVERT(varchar(4), @FiscalYear) + '-10-01'''',''''YYYY-mm-DD'''')AND
    f.AWARD_END_DATE > TO_DATE(''''' + CONVERT(varchar(4), @FiscalYear - 1) + '-10-01'''',''''YYYY-mm-DD'''')
INNER JOIN FINANCE.SUB_FUND_GROUP sfg ON 
    sfg.FISCAL_YEAR = 9999 and sfg.FISCAL_PERIOD = ''''--'''' 
    AND sfg.SUB_FUND_GROUP_NUM= f.SUB_FUND_GROUP_NUM AND sfg.ACTIVE_IND = ''''Y''''
INNER JOIN FINANCE.SUB_FUND_GROUP_TYPE sfgt ON 
	sfgt.SUB_FUND_GROUP_TYPE_CODE = sfg.SUB_FUND_GROUP_TYPE_CODE AND 
	sfgt.FEDERAL_IND = ''''Y''''
WHERE REMOVED_DATE IS NULL 
AND ((END_FISCAL_YEAR >= ' + CONVERT(varchar(4), @FiscalYear) + ' OR END_FISCAL_YEAR IS NULL) AND 
	(START_FISCAL_YEAR <= ' + CONVERT(varchar(4), @FiscalYear + 1) + ' OR START_FISCAL_YEAR IS NULL)) 
'')
	) FIS_DS_ORGS on Orgs.OrganizationPK = FIS_DS_ORGS.OrganizationPK

	WHEN MATCHED THEN UPDATE set
	   Orgs.Level = FIS_DS_ORGS.Level
	  ,Orgs.Name = FIS_DS_ORGS.Name
      ,Orgs.[Type] = FIS_DS_ORGS.[Type]
      ,Orgs.[BeginDate] = FIS_DS_ORGS.[BeginDate]
      ,Orgs.[EndDate] = FIS_DS_ORGS.[EndDate]
      ,Orgs.[HomeDeptNum] = FIS_DS_ORGS.[HomeDeptNum]
      ,Orgs.[HomeDeptName] = FIS_DS_ORGS.[HomeDeptName]
      ,Orgs.[UpdateDate] = FIS_DS_ORGS.[UpdateDate]
      ,Orgs.[Chart1] = FIS_DS_ORGS.[Chart1]
      ,Orgs.[Org1] = FIS_DS_ORGS.[Org1]
      ,Orgs.[Name1] = FIS_DS_ORGS.[Name1]
      ,Orgs.[Chart2] = FIS_DS_ORGS.[Chart2]
      ,Orgs.[Org2] = FIS_DS_ORGS.[Org2]
      ,Orgs.[Name2] = FIS_DS_ORGS.[Name2]
      ,Orgs.[Chart3] = FIS_DS_ORGS.[Chart3]
      ,Orgs.[Org3] = FIS_DS_ORGS.[Org3]
      ,Orgs.[Name3] = FIS_DS_ORGS.[Name3]
      ,Orgs.[Chart4] = FIS_DS_ORGS.[Chart4]
      ,Orgs.[Org4] = FIS_DS_ORGS.[Org4]
      ,Orgs.[Name4] = FIS_DS_ORGS.[Name4]
      ,Orgs.[Chart5] = FIS_DS_ORGS.[Chart5]
      ,Orgs.[Org5] = FIS_DS_ORGS.[Org5]
      ,Orgs.[Name5] = FIS_DS_ORGS.[Name5]
      ,Orgs.[Chart6] = FIS_DS_ORGS.[Chart6]
      ,Orgs.[Org6] = FIS_DS_ORGS.[Org6]
      ,Orgs.[Name6] = FIS_DS_ORGS.[Name6]
      ,Orgs.[Chart7] = FIS_DS_ORGS.[Chart7]
      ,Orgs.[Org7] = FIS_DS_ORGS.[Org7]
      ,Orgs.[Name7] = FIS_DS_ORGS.[Name7]
      ,Orgs.[Chart8] = FIS_DS_ORGS.[Chart8]
      ,Orgs.[Org8] = FIS_DS_ORGS.[Org8]
      ,Orgs.[Name8] = FIS_DS_ORGS.[Name8]
      ,Orgs.[Chart9] = FIS_DS_ORGS.[Chart9]
      ,Orgs.[Org9] = FIS_DS_ORGS.[Org9]
      ,Orgs.[Name9] = FIS_DS_ORGS.[Name9]
      ,Orgs.[Chart10] = FIS_DS_ORGS.[Chart10]
      ,Orgs.[Org10] = FIS_DS_ORGS.[Org10]
      ,Orgs.[Name10] = FIS_DS_ORGS.[Name10]
      ,Orgs.[Chart11] = FIS_DS_ORGS.[Chart11]
      ,Orgs.[Org11] = FIS_DS_ORGS.[Org11]
      ,Orgs.[Name11] = FIS_DS_ORGS.[Name11]
      ,Orgs.[Chart12] = FIS_DS_ORGS.[Chart12]
      ,Orgs.[Org12] = FIS_DS_ORGS.[Org12]
      ,Orgs.[Name12] = FIS_DS_ORGS.[Name12]
      ,Orgs.[ActiveIndicator] = FIS_DS_ORGS.[ActiveInd]
      ,Orgs.[LastUpdateDate] = FIS_DS_ORGS.[LastUpdateDate]
  
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
	;
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END