

-- =============================================
-- Author:		Ken Taylor
-- Create date: December 13, 2019
-- Description:	Merges the Organizations table so we can use it for figuring out
-- the VETM Scientist Years and VETM Cost Share Scientist Years, since we
-- do not normally load VETM organization information into our local FIS DataMart.
--
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_MergeVetMedOrgs]
		@FiscalYear = 2019,
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--	2020-09-22 by kjt: Shortened Organizations to Orgs as text was too long for OPENQUERY.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeVetMedOrgs]
	@FiscalYear int = 2019, 
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
				''SELECT 
					Orgs.FISCAL_YEAR Year,
					Orgs.FISCAL_PERIOD Period,
					Orgs.CHART_NUM Chart,
					Orgs.ORG_ID Org,
					Orgs.ORG_HIERARCHY_LEVEL Org_Level,
					Orgs.ORG_NAME Org_Name,
					Orgs.ORG_TYPE_CODE Org_Type,
					TO_CHAR(Orgs.ORG_BEGIN_DATE) Begin_Date,
					TO_CHAR(Orgs.ORG_END_DATE) End_Date,
					Orgs.HOME_DEPARTMENT_NUM Home_Dept_Num,
					Orgs.HOME_DEPARTMENT_PRIMARY_NAME Home_Dept_Name,
					TO_CHAR(Orgs.ORG_UPDATE_DATE) Update_Date,
					Orgs.CHART_NUM_LEVEL_1 Chart_1,
					Orgs.ORG_ID_LEVEL_1 Org_1,
					Orgs.ORG_NAME_LEVEL_1 Name_1,
					Orgs.CHART_NUM_LEVEL_2 Chart_2,
					Orgs.ORG_ID_LEVEL_2 Org_2,
					Orgs.ORG_NAME_LEVEL_2 Name_2,
					Orgs.CHART_NUM_LEVEL_3 Chart_3,
					Orgs.ORG_ID_LEVEL_3 Org_3,
					Orgs.ORG_NAME_LEVEL_3 Name_3,
					Orgs.CHART_NUM_LEVEL_4 Chart_4,
					Orgs.ORG_ID_LEVEL_4 Org_4,
					Orgs.ORG_NAME_LEVEL_4 Name_4,
					Orgs.CHART_NUM_LEVEL_5 Chart_5,
					Orgs.ORG_ID_LEVEL_5 Org_5,
					Orgs.ORG_NAME_LEVEL_5 Name_5,
					Orgs.CHART_NUM_LEVEL_6 Chart_6,
					Orgs.ORG_ID_LEVEL_6 Org_6,
					Orgs.ORG_NAME_LEVEL_6 Name_6,
					Orgs.CHART_NUM_LEVEL_7 Chart_7,
					Orgs.ORG_ID_LEVEL_7 Org_7,
					Orgs.ORG_NAME_LEVEL_7 Name_7,
					Orgs.CHART_NUM_LEVEL_8 Chart_8,
					Orgs.ORG_ID_LEVEL_8 Org_8,
					Orgs.ORG_NAME_LEVEL_8 Name_8,
					Orgs.CHART_NUM_LEVEL_9 Chart_9,
					Orgs.ORG_ID_LEVEL_9 Org_9,
					Orgs.ORG_NAME_LEVEL_9 Name_9,
					Orgs.CHART_NUM_LEVEL_10 Chart_10,
					Orgs.ORG_ID_LEVEL_10 Org_10,
					Orgs.ORG_NAME_LEVEL_10 Name_10,
					Orgs.CHART_NUM_LEVEL_11 Chart_11,
					Orgs.ORG_ID_LEVEL_11 Org_11,
					Orgs.ORG_NAME_LEVEL_11 Name_11,
					Orgs.CHART_NUM_LEVEL_12 Chart_12,
					Orgs.ORG_ID_LEVEL_12 Org_12,
					Orgs.ORG_NAME_LEVEL_12 Name_12,
					Orgs.ACTIVE_IND,
					Orgs.FISCAL_YEAR || ''''|'''' || Orgs.FISCAL_PERIOD || ''''|'''' || Orgs.CHART_NUM  || ''''|'''' || Orgs.ORG_ID as Organization_PK,
					Orgs.ds_last_update_date LAST_UPDATE_DATE
				FROM 
					FINANCE.ORGANIZATION_HIERARCHY Orgs 
				INNER JOIN (
				select DISTINCT oh.CHART_NUM, oh.ORG_ID
 from ORGANIZATION_HIERARCHY oh
inner join ORGANIZATION_ACCOUNT oa on 
    oa.CHART_NUM = oh.CHART_NUM and 
    oa.ORG_ID = oh.ORG_ID and
    oa.FISCAL_YEAR = oh.FISCAL_YEAR and
    oa.FISCAL_PERIOD = oh.FISCAL_PERIOD
inner join FINANCE.OP_FUND f ON 
    f.FISCAL_YEAR = oa.FISCAL_YEAR and 
    f.FISCAL_PERIOD = oa.FISCAL_PERIOD and 
    f.OP_LOCATION_CODE = oa.OP_LOCATION_CODE and 
    f.OP_FUND_NUM = oa.OP_FUND_NUM 
INNER JOIN FINANCE.AWARD A ON 
    a.UC_LOC_CD = f.OP_LOCATION_CODE AND
    a.UC_FUND_NBR = f.OP_FUND_NUM AND
    a.fiscal_year = f.FISCAL_YEAR AND
    a.fiscal_period = f.FISCAL_PERIOD  
where 
    oh.FISCAL_YEAR = 9999 and oh.FISCAL_PERIOD = ''''--'''' and 
    oh.ORG_ID_LEVEL_4 = ''''VETM'''' AND 
    (oa.HIGHER_ED_FUNC_CODE IN (''''ORES'''', ''''OAES'''') OR SUBSTR(oa.A11_ACCT_NUM,1, 2) BETWEEN ''''44'''' AND ''''59'''')
	) t1 ON t1.CHART_NUM = Orgs.CHART_NUM AND t1.ORG_ID = Orgs.Org_ID
	WHERE Orgs.Fiscal_Year = 9999 and Orgs.FIscal_Period = ''''--''''
'')
	) FIS_DS_ORGS on Orgs.OrganizationPK = FIS_DS_ORGS.OrganizationPK

	WHEN MATCHED THEN UPDATE set
	   Orgs.Level = FIS_DS_Orgs.Level
	  ,Orgs.Name = FIS_DS_Orgs.Name
      ,Orgs.[Type] = FIS_DS_Orgs.[Type]
      ,Orgs.[BeginDate] = FIS_DS_Orgs.[BeginDate]
      ,Orgs.[EndDate] = FIS_DS_Orgs.[EndDate]
      ,Orgs.[HomeDeptNum] = FIS_DS_Orgs.[HomeDeptNum]
      ,Orgs.[HomeDeptName] = FIS_DS_Orgs.[HomeDeptName]
      ,Orgs.[UpdateDate] = FIS_DS_Orgs.[UpdateDate]
      ,Orgs.[Chart1] = FIS_DS_Orgs.[Chart1]
      ,Orgs.[Org1] = FIS_DS_Orgs.[Org1]
      ,Orgs.[Name1] = FIS_DS_Orgs.[Name1]
      ,Orgs.[Chart2] = FIS_DS_Orgs.[Chart2]
      ,Orgs.[Org2] = FIS_DS_Orgs.[Org2]
      ,Orgs.[Name2] = FIS_DS_Orgs.[Name2]
      ,Orgs.[Chart3] = FIS_DS_Orgs.[Chart3]
      ,Orgs.[Org3] = FIS_DS_Orgs.[Org3]
      ,Orgs.[Name3] = FIS_DS_Orgs.[Name3]
      ,Orgs.[Chart4] = FIS_DS_Orgs.[Chart4]
      ,Orgs.[Org4] = FIS_DS_Orgs.[Org4]
      ,Orgs.[Name4] = FIS_DS_Orgs.[Name4]
      ,Orgs.[Chart5] = FIS_DS_Orgs.[Chart5]
      ,Orgs.[Org5] = FIS_DS_Orgs.[Org5]
      ,Orgs.[Name5] = FIS_DS_Orgs.[Name5]
      ,Orgs.[Chart6] = FIS_DS_Orgs.[Chart6]
      ,Orgs.[Org6] = FIS_DS_Orgs.[Org6]
      ,Orgs.[Name6] = FIS_DS_Orgs.[Name6]
      ,Orgs.[Chart7] = FIS_DS_Orgs.[Chart7]
      ,Orgs.[Org7] = FIS_DS_Orgs.[Org7]
      ,Orgs.[Name7] = FIS_DS_Orgs.[Name7]
      ,Orgs.[Chart8] = FIS_DS_Orgs.[Chart8]
      ,Orgs.[Org8] = FIS_DS_Orgs.[Org8]
      ,Orgs.[Name8] = FIS_DS_Orgs.[Name8]
      ,Orgs.[Chart9] = FIS_DS_Orgs.[Chart9]
      ,Orgs.[Org9] = FIS_DS_Orgs.[Org9]
      ,Orgs.[Name9] = FIS_DS_Orgs.[Name9]
      ,Orgs.[Chart10] = FIS_DS_Orgs.[Chart10]
      ,Orgs.[Org10] = FIS_DS_Orgs.[Org10]
      ,Orgs.[Name10] = FIS_DS_Orgs.[Name10]
      ,Orgs.[Chart11] = FIS_DS_Orgs.[Chart11]
      ,Orgs.[Org11] = FIS_DS_Orgs.[Org11]
      ,Orgs.[Name11] = FIS_DS_Orgs.[Name11]
      ,Orgs.[Chart12] = FIS_DS_Orgs.[Chart12]
      ,Orgs.[Org12] = FIS_DS_Orgs.[Org12]
      ,Orgs.[Name12] = FIS_DS_Orgs.[Name12]
      ,Orgs.[ActiveIndicator] = FIS_DS_Orgs.[ActiveInd]
      ,Orgs.[LastUpdateDate] = FIS_DS_Orgs.[LastUpdateDate]
  
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