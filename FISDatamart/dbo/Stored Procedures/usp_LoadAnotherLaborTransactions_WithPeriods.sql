



-- =============================================
-- Author:		Ken Taylor
-- Create date: October 9, 2020
-- Description:	Loads the AnotherLaborTransactions table so we can later use it for figuring out
-- the labor portion of the expenses,  Note that this version uses UC Path as the data source.
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadAnotherLaborTransactions_WithPeriods]
		@FiscalYear = 2020,
		@IsDebug = 0,
		@TableName = 'AnotherLaborTransactions_WithPeriods' -- Can change table for testing purposes

SET NOCOUNT ON;
SELECT	'Return Value' = @return_value
SET NOCOUNT OFF;

GO

*/
-- Modifications
--	2020-10-09 by kjt: Total rewrite of logic to use UC Path as a data source, plus revised 
--	to run on caes-elzar and execute via a synonym from caes-donbot because it took abount 
--	2-1/2 hours to run from caes-donbot, and abount 30 minutes to run from caes-elzar.
--	2020-10-12 by kjt: Changed to use FISDataMart.dbo.RICE_UC_KRIM_PERSON_V Vs. PPS DataMart's 
--	version so that all operations could be kept in FISDataMart.
--	2020-10-20 by kjt: Added PAID_PERCENT, and ERN_DERIVED_PERCENT columns as addition of hours
--		resulted in > 1.00 FTE for a number of persons due to UC Path rounding issues.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadAnotherLaborTransactions_WithPeriods] 
	@FiscalYear int = 2020, 
	@IsDebug bit = 0,
	@TableName varchar(50) = 'AnotherLaborTransactionsWithPeriods'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET ANSI_NULLS ON

	SET QUOTED_IDENTIFIER ON

	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @OriginalTableName varchar(250) = @TableName
	SELECT @TableName += '_Temp'

	--SELECT @TableName += '_FFY' + CONVERT(char(4),@FiscalYear) + '_caes-elzar_test after_empl_Id_update'

	IF (NOT EXISTS (
		SELECT * 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = 'dbo' 
        AND  TABLE_NAME = @TableName
		)
	)
	BEGIN
		SELECT @TSQL = '
		CREATE TABLE [dbo].[' + @TableName + '] (
			[LaborTransactionId] [varchar](125) NOT NULL,
			FiscalYear [int] NOT NULL.
			FiscalPeriod varchar(2) NOT NULL,
			[Chart] [varchar](2) NULL,
			[Account] [varchar](7) NULL,
			[SubAccount] [varchar](5) NULL,
			[Org] [varchar](4) NULL,
			[ObjConsol] [varchar](4) NULL,
			[Object] [varchar](4) NOT NULL,
			[FinanceDocTypeCd] [varchar](4) NULL,
			[DosCd] [varchar](3) NULL,
			[EmployeeID] [varchar](10) NULL,
			[PPS_ID] [varchar](9) NULL,
			[EmployeeName] [varchar](100) NULL,
			[POSITION_NBR] [nvarchar](8) NULL, -- New field used for populating title code using UCP Jobcode 
			[EFFDT] [datetime2](7) NULL, -- New field used for populating title code and/or employee name using UCP Jobcode or employee name fields.
			[TitleCd] [varchar](4) NULL,
			[RateTypeCd] [varchar](1) NULL, --Don''t really need this since everything is now hourly.
			[Hours] [numeric](18,6) NOT NULL,
			[Amount] [money] NULL,
			[Payrate] [numeric](17, 4) NULL,
			[CalculatedFTE] [numeric](9,6) NULL,
			[PayPeriodEndDate] [datetime2](7) NULL,
			[FringeBenefitSalaryCd] [varchar](1) NULL,
			[AnnualReportCode] [varchar](6) NULL,
			[ExcludedByARC] [bit] NULL,
			[ExcludedByOrg] [bit] NULL,
			[ExcludedByAccount] [bit] NULL,
			[ExcludedByObjConsol] [bit] NULL,
			[ExcludedByDOS] [bit] NULL,
			[IncludeInFTECalc] [bit] NULL,
			[ReportingYear] [int] NULL,
			[School] varchar(4) NULL,
			[OrgId] varchar(4) NULL,
			[PAID_PERCENT] numeric(7,4) NULL,
			[ERN_DERIVED_PERCENT] numeric(7,4) NULL
		 CONSTRAINT [PK_' + @TableName + ' ] PRIMARY KEY CLUSTERED 
		(
			[LaborTransactionId] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]


		 CREATE NONCLUSTERED INDEX  [' + @TableName + '_ChartOrg_NCLINDX] 
		  ON [' + @TableName + ']
		 (Chart, Org) 
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		 CREATE NONCLUSTERED INDEX  [' + @TableName + '_EmployeeId_NCLINDX] 
		  ON [' + @TableName + ']
		 (EmployeeId) 
		 WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]


		CREATE NONCLUSTERED INDEX [' + @TableName + '_TitleCd_NCLINDX] 
		ON [dbo].[' + @TableName + ']
		(
			[TitleCd] ASC
		) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]


		CREATE NONCLUSTERED INDEX [' + @TableName + '_EmpName_EmpId_CVIDX] 
		ON [dbo].[' + @TableName + ']
		(
			[EmployeeName] ASC
		)
		INCLUDE ([EmployeeID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		'
	END
	ELSE 
	BEGIN
		SELECT @TSQL = '
		TRUNCATE TABLE [dbo].[' + @TableName + ']
'
	END

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	--DECLARE @ARCCodesString varchar(MAX) = (SELECT [dbo].[udf_ArcCodesString](DEFAULT)) -- Use this on AD419 on caes-donbot

	DECLARE @QueryParameterTable AS QueryParameterTableType;
	INSERT INTO @QueryParameterTable
	SELECT ARCCode FROM ARCCodes
	DECLARE @ARCCodesString varchar(MAX) =  (
		SELECT dbo.udf_CommaDelimitedStringFromTableType(@QueryParameterTable, 2)
	)

	SELECT @TSQL = '
	INSERT INTO [dbo].[' + @TableName + '](     
		   [LaborTransactionId]
		  ,FiscalYear
		  ,FiscalPeriod
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,FinanceDocTypeCd
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ReportingYear]
		  ,OrgId
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
	 )

		SELECT DISTINCT 
		t1.[JOURNAL_ID] + ''-'' + 
			CONVERT(nvarchar(50), t1.[JOURNAL_LINE]) + ''-'' + 
			t1.[UC_ADDL_SEQ] + ''-'' + 
			CONVERT(nvarchar(8), t1.POSITION_NBR) [LaborTransactionId],
		FISCAL_YEAR [FiscalYear],
		ACCOUNTING_PERIOD (FiscalPeriod],
		[OPERATING_UNIT] [Chart],
		RIGHT([DEPTID_CF], 7) [Account],
		[CLASS_FLD] [SubAccount],
		RIGHT([UC_DEPTID_ROLLUP], 4) [Org],
		t1.FIN_CONS_OBJ_CD [ObjConsol],
		RIGHT(ACCOUNT,4) [Object],
		''PAY'' FinanceDocTypeCd,
		[ERNCD] [DOSCd],
		t1.[EMPLID] [EmployeeID],
		'''' EmployeeName,	-- Need to include this as the field can''t be null.
		t1.[POSITION_NBR],
		t1.[EFFDT],
		''H'' [RateTypeCd],	-- Need to include this as the field can''t be null.
		Hours1 Hours,
		MONETARY_AMOUNT Amount,
		CASE WHEN Hours1 <> 0 THEN round(MONETARY_AMOUNT/Hours1, 3) ELSE 0 END Payrate,
		CASE WHEN Hours1 <> 0 THEN ROUND(hours1/2088, 6) ELSE 0 END [CalculatedFTE],
		UC_EARN_END_DT [PayPeriodEndDate],
		''S'' [FringeBenefitSalaryCd],
		t2.ANNUAL_REPORT_CODE [AnnualReportCode], 
		0 AS [ExcludedByARC],
		' + CONVERT(char(4), @FiscalYear) + ' [ReportingYear],
		t2.ORG_ID OrgId,
		t1.UC_PCT_TOT_PAY PAID_PERCENT, 
		t1.UC_DRV_EFT_PCT ERN_DERIVED_PERCENT
 
	  FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
		SELECT * FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
			(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + '  AND t1.ACCOUNTING_PERIOD BETWEEN 4 AND 13) OR
			(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND t1.ACCOUNTING_PERIOD BETWEEN 1 AND 3) 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 
		ORDER BY t1.JOURNAL_ID, t1.JOURNAL_LINE, t1.UC_ADDL_SEQ, t1.POSITION_NBR 
	  '') t1
	  INNER JOIN 
	  (
		SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE, ORG_ID
		FROM OPENQUERY([FIS_DS], ''
			SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID
			FROM FINANCE.ORGANIZATION_ACCOUNT A
			WHERE A.FISCAL_YEAR = 9999 AND 
				A.FISCAL_PERIOD = ''''--'''' AND
				A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV'''' AND 
				A.ANNUAL_REPORT_CODE IN (' + @ARCCodesString + ')
		'')
	   ) t2 ON t1.OPERATING_UNIT =  t2.CHART_NUM AND
			RIGHT([DEPTID_CF], 7) = t2.ACCT_NUM

	ORDER BY [LaborTransactionId]
	 '
 	IF @IsDebug = 1  
	BEGIN
		PRINT @TSQL
	END
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
	INSERT INTO [dbo].[' + @TableName + '](     
		   [LaborTransactionId]
		  ,FiscalYear
		  ,FiscalPeriod
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,FinanceDocTypeCd
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ReportingYear]
		  ,OrgId
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
	 )

		SELECT DISTINCT 
		t1.[JOURNAL_ID] + ''-'' + 
			CONVERT(nvarchar(50), t1.[JOURNAL_LINE]) + ''-'' + 
			t1.[UC_ADDL_SEQ] + ''-'' + 
			CONVERT(nvarchar(8), t1.POSITION_NBR) [LaborTransactionId],
	    FISCAL_YEAR [FiscalYear],
		ACCOUNTING_PERIOD (FiscalPeriod],
		[OPERATING_UNIT] [Chart],
		RIGHT([DEPTID_CF], 7) [Account],
		[CLASS_FLD] [SubAccount],
		RIGHT([UC_DEPTID_ROLLUP], 4) [Org],
		t1.FIN_CONS_OBJ_CD [ObjConsol],
		RIGHT(ACCOUNT,4) [Object],
		''PAY'' FinanceDocTypeCd,
		''XXX'' [DOSCd],
		t1.[EMPLID] [EmployeeID],
		'''' EmployeeName,	-- Need to include this as the field can''t be null.
		t1.[POSITION_NBR],
		t1.[EFFDT],
		''H'' [RateTypeCd],	-- Need to include this as the field can''t be null.
		0 [Hours],
		MONETARY_AMOUNT [Amount],
		0 [Payrate],
		0 [CalculatedFTE],
		UC_EARN_END_DT [PayPeriodEndDate],
		''F'' [FringeBenefitSalaryCd],
		t2.ANNUAL_REPORT_CODE [AnnualReportCode], 
		0 AS [ExcludedByARC],
		' + CONVERT(char(4), @FiscalYear) + ' [ReportingYear],
		t2.ORG_ID OrgId,
		0 AS PAID_PERCENT,
		0 AS ERN_DERIVED_PERCENT
 
	  FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
		SELECT * FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
			SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
			t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
			t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
			(
			(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + '  AND t1.ACCOUNTING_PERIOD BETWEEN 4 AND 13) OR
			(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + '  AND t1.ACCOUNTING_PERIOD BETWEEN 1 AND 3) 
			) AND
			t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
			t1.DML_IND <> ''''D'''' AND
			SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 
		ORDER BY t1.JOURNAL_ID, t1.JOURNAL_LINE, t1.UC_ADDL_SEQ, t1.POSITION_NBR 
	  '') t1
	  INNER JOIN 
	  (
		SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE, ORG_ID
		FROM OPENQUERY([FIS_DS], ''
			SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID
			FROM FINANCE.ORGANIZATION_ACCOUNT A
			WHERE A.FISCAL_YEAR = 9999 AND 
				A.FISCAL_PERIOD = ''''--'''' AND
				A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV'''' AND 
				A.ANNUAL_REPORT_CODE IN (' + @ARCCodesString + ')	
		'')
	   ) t2 ON t1.OPERATING_UNIT =  t2.CHART_NUM AND
			RIGHT([DEPTID_CF], 7) = t2.ACCT_NUM
	
	ORDER BY [LaborTransactionId]
	 '
 	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	 SELECT @TSQL = '
	  UPDATE [dbo].[' + @TableName + ']
	  SET ORG = OrgID
	  WHERE Org = ''-ANR'' AND Chart = ''L''

	 UPDATE [dbo].[' + @TableName + ']
	 SET 
		School = t2.ORG_ID_LEVEL_4, 
		ExcludedByOrg = CASE WHEN t2.ORG_ID_LEVEL_4 IN (''AAES'', ''BIOS'') THEN 0 ELSE 1 END 
	 FROM [dbo].[' + @TableName + '] t1
	 INNER JOIN 
	  (
		SELECT CHART_NUM, ORG_ID, ORG_ID_LEVEL_4
		FROM OPENQUERY([FIS_DS], ''
			SELECT O.CHART_NUM, O.ORG_ID, O.ORG_ID_LEVEL_4
			FROM FINANCE.ORGANIZATION_HIERARCHY O
		
			WHERE O.FISCAL_YEAR = 9999 AND 
				O.FISCAL_PERIOD = ''''--''''
		'')
	   ) t2 ON t1.Chart = t2.CHART_NUM AND
			ORG		= t2.ORG_ID
		WHERE t1.School IS NULL
	  '
   	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
	UPDATE [dbo].[' + @TableName + ']
	SET ExcludedByDOS = t2.ExcludedByDOS
	FROM [dbo].[' + @TableName + '] t1
	INNER JOIN (
		SELECT DISTINCT t1.DosCd, t2.IncludeInAD419FTE, 
		CASE t2.IncludeInAD419FTE WHEN 1 THEN 0 WHEN 0 THEN 1 ELSE NULL END AS ExcludedByDOS
		FROM [dbo].[' + @TableName + '] t1
		LEFT OUTER JOIN dbo.DOS_Codes t2
			ON t1.DosCd = t2.DOS_Code 
		WHERE t1.ExcludedByDOS IS NULL
	) t2 ON t1.DosCd = t2.DosCd
	WHERE t1.ExcludedByDOS IS NULL
'
		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)

	SELECT @TSQL = '
	UPDATE  [dbo].[' + @TableName + '] 
	SET ExcludedByAccount = CASE WHEN t2.Account IS NULL THEN 0 ELSE 1 END
	FROM [dbo].[' + @TableName + '] t1
	LEFT OUTER JOIN (
		SELECT DISTINCT Chart, Account 
		FROM [dbo].ArcCodeAccountExclusions
		) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	WHERE ExcludedByAccount IS NULL
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
	UPDATE  [dbo].[' + @TableName + '] 
	SET ExcludedByObjConsol = CASE WHEN t2.Obj_Consolidatn_Num IS NOT NULL THEN 0 ELSE 1 END
	FROM [dbo].[' + @TableName + ']  t1
	LEFT OUTER JOIN [dbo].ConsolCodesForLaborTransactions t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num 
	WHERE t1.ExcludedByObjConsol IS NULL
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
	UPDATE [dbo].[' + @TableName + ']
			SET PPS_ID = t2.EmployeeId
	FROM [dbo].[' + @TableName + '] t1
	INNER JOIN (
		SELECT  [EMPLID]
			,[BUSINESS_UNIT]
			,[UC_EXT_SYSTEM_ID] EmployeeId
			,[EFFDT]
			,[EFF_STATUS]
			,[UC_EXT_SYSTEM_ID]
     
		FROM OPENQUERY([FIS_BISTG_PRD (CAESAPP_HCMODS_APPUSER)], ''
		SELECT * FROM CAESAPP_HCMODS.PS_UC_EXT_SYSTEM_V t1
		WHERE UC_EXT_SYSTEM = ''''PPS_ID'''' AND EFFDT =
		(
			SELECT MAX(EFFDT) FROM CAESAPP_HCMODS.PS_UC_EXT_SYSTEM_V  t2
			WHERE t1.BUSINESS_UNIT = t2.BUSINESS_UNIT AND
				t1.UC_EXT_SYSTEM = t2.UC_EXT_SYSTEM AND 
				t1.EMPLID = t2.EMPLID AND
				t2.DML_IND <> ''''D'''' AND
				t2.EFFDT <= CURRENT_DATE
		)
		'')
	) t2 ON t1.EmployeeID = t2.EMPLID
	WHERE t1.PPS_ID IS NULL
'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	  SELECT @TSQL = '
		UPDATE [dbo].[' + @TableName + ']
		SET PPS_ID = t2.PPS_ID
		FROM [dbo].[' + @TableName + '] t1
		INNER JOIN (
			SELECT DISTINCT t1.EmployeeName,  t2.PERSON_NM, t2.EMPLOYEE_Id EmployeeId, t2.PPS_ID
			FROM [dbo].[' + @TableName + '] t1
			LEFT OUTER JOIN [dbo].[RICE_UC_KRIM_PERSON_V] t2
				ON t1.EmployeeId = t2.EMPLOYEE_ID
			WHERE t1.PPS_ID IS NULL AND t2.PPS_ID IS NOT NULL
		) t2 ON t1.EmployeeId = t2.EmployeeId
		WHERE t1.PPS_ID IS NULL AND t2.PPS_ID IS NOT NULL
	'
	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	  SELECT @TSQL = '
	  UPDATE [dbo].[' + @TableName + ']
	  SET EmployeeName = t2.EmployeeName
	  FROM [dbo].[' + @TableName + '] t1
	  INNER JOIN (
			SELECT DISTINCT 
				t1.EmployeeId,
				t2.LAST_NAME,
				t2.FIRST_NAME,
				t2.MIDDLE_NAME,
				t2.NAME_SUFFIX,
				t2.LAST_NAME + '','' + t2.FIRST_NAME + RTRIM('' '' + t2.MIDDLE_NAME) + RTRIM('' '' + t2.NAME_SUFFIX) EmployeeName
			FROM [dbo].[' + @TableName + '] t1
			INNER JOIN  OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
				SELECT DISTINCT 
					EMPLID, 
					LAST_NAME,
					FIRST_NAME,
					MIDDLE_NAME,
					NAME_SUFFIX
				
				FROM CAES_HCMODS.PS_UC_LL_EMPL_DTL_V t2
				WHERE EFFDT = (
					SELECT MAX(EFFDT)
					FROM  CAES_HCMODS.PS_UC_LL_EMPL_DTL_V  t3 
					WHERE
						t2.EMPLID = t3.EMPLID AND T3.DML_IND <> ''''D'''' AND
						t3.EFFDT <= CURRENT_DATE
				)
			'') t2 ON
				t1.EmployeeID = t2.EMPLID
			WHERE t1.EmployeeName IS NULL OR t1.EmployeeName LIKE ''''
		) t2 ON t1.EmployeeID = t2.EmployeeID
		WHERE  t1.EmployeeName IS NULL OR t1.EmployeeName = ''''  

		SELECT count(*) Blank_EmployeeNames FROM [dbo].[' + @TableName + ']
		WHERE EmployeeName = '''' OR EmployeeName IS NULL
	'
		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)
	--(503729 rows affected)
	--(1 row affected)


	  SELECT @TSQL = '
	  UPDATE [dbo].[' + @TableName + ']
	  SET 
		TitleCd = RIGHT(t2.JOBCODE,4)
	  FROM [dbo].[' + @TableName + '] t1
	  INNER JOIN (
			SELECT DISTINCT 
				t1.EmployeeId,
				t2.JOBCODE, 
				t2.POSITION_NBR
			FROM [dbo].[' + @TableName + '] t1
			INNER JOIN  OPENQUERY([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)], ''
				SELECT DISTINCT 
					EMPLID, 
					JOBCODE, 
					POSITION_NBR
				FROM CAES_HCMODS.PS_UC_LL_EMPL_DTL_V t2
				WHERE EFFDT = (
					SELECT MAX(EFFDT)
					FROM  CAES_HCMODS.PS_UC_LL_EMPL_DTL_V  t3 
					WHERE
						t2.EMPLID = t3.EMPLID AND T3.DML_IND <> ''''D'''' AND
						t3.EFFDT <= CURRENT_DATE
				)
			'') t2 ON
				t1.EmployeeID = t2.EMPLID
			WHERE t1.TitleCD IS NULL OR t1.TitleCd LIKE ''''
		) t2 ON t1.EmployeeID = t2.EmployeeID
		WHERE t1.TITLECD IS NULL OR t1.TITLECD LIKE ''''

		SELECT COUNT(*) Blank_TitleCodes
		FROM [dbo].[' + @TableName + '] t1
		WHERE t1.TitleCd IS NULL OR t1.TitleCd LIKE '' '' OR t1.TitleCd LIKE ''''
	'
		IF @IsDebug = 1  
			PRINT @TSQL
		ELSE 
			EXEC(@TSQL)
	--(503729 rows affected)

	  SELECT @TSQL = '
		DECLARE @NullDosCodeCount int = 
		(SELECT Count(DOSCd) [NumberOfDosCodesWithoutClassification:] FROM [dbo].[' + @TableName + ']
		WHERE ExcludedByDOS IS NULL AND 
			CalculatedFTE <> 0 AND 
			ExcludedByOrg = 0 AND 
			ExcludedByARC = 0 AND 
			ExcludedByAccount = 0 AND
			ExcludedByObjConsol = 0)

		IF @NullDosCodeCount = 0 
		BEGIN
		  UPDATE [dbo].[' + @TableName + ']
		  SET IncludeInFTECalc = CASE WHEN 
				ExcludedByARC = 0 AND 
				ExcludedByOrg = 0 AND 
				ExcludedByAccount = 0 AND
				ExcludedByObjConsol = 0 AND
				COALESCE(ExcludedByDOS,1) = 0 THEN 1 ELSE 0 END
			WHERE IncludeInFTECalc IS NULL

			SELECT ''Completed setting IncludeInFTECalc flag'' AS [Message:]
		END 
		ELSE
		BEGIN
			SELECT ''Unable to set IncludeInFTECalc because not all flags are set.'' AS [Message:]

			SELECT Count(DOSCd) [NumberOfDosCodesWithoutClassification:] FROM [dbo].[' + @TableName + ']
			WHERE ExcludedByDOS IS NULL AND 
				CalculatedFTE <> 0 AND 
				ExcludedByOrg = 0 AND 
				ExcludedByARC = 0 AND 
				ExcludedByAccount = 0 AND
				ExcludedByObjConsol = 0
		END
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;

	SELECT @TSQL = '
	DECLARE @NewRecordsCount int = (SELECT count(*) 
	FROM [dbo].[' + @TableName + '] t1
	WHERE NOT EXISTS (
		SELECT 1 
		FROM [dbo].[AnotherLaborTransactions] t2
		WHERE t1.[LaborTransactionId] = t2.[LaborTransactionId] AND
			t1.ReportingYear = t2.ReportingYear
		)
	)

	IF @NewRecordsCount > 0
	BEGIN
		SET NOCOUNT ON; 

		INSERT INTO [dbo].[AnotherLaborTransactions] (
		[LaborTransactionId]
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[PPS_ID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ExcludedByOrg]
		  ,[ExcludedByAccount]
		  ,[ExcludedByObjConsol]
		  ,[ExcludedByDOS]
		  ,[IncludeInFTECalc]
		  ,[ReportingYear]
		  ,[School]
		  ,[OrgId]
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
		)
		SELECT [LaborTransactionId]
		  ,[Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[Org]
		  ,[ObjConsol]
		  ,[Object]
		  ,[FinanceDocTypeCd]
		  ,[DosCd]
		  ,[EmployeeID]
		  ,[PPS_ID]
		  ,[EmployeeName]
		  ,[POSITION_NBR]
		  ,[EFFDT]
		  ,[TitleCd]
		  ,[RateTypeCd]
		  ,[Hours]
		  ,[Amount]
		  ,[Payrate]
		  ,[CalculatedFTE]
		  ,[PayPeriodEndDate]
		  ,[FringeBenefitSalaryCd]
		  ,[AnnualReportCode]
		  ,[ExcludedByARC]
		  ,[ExcludedByOrg]
		  ,[ExcludedByAccount]
		  ,[ExcludedByObjConsol]
		  ,[ExcludedByDOS]
		  ,[IncludeInFTECalc]
		  ,[ReportingYear]
		  ,[School]
		  ,[OrgId]
		  ,[PAID_PERCENT]
		  ,[ERN_DERIVED_PERCENT]
		FROM [dbo].[' + @TableName + '] t1
		WHERE NOT EXISTS (
			SELECT 1 
			FROM [dbo].[' + @OriginalTableName + '] t2
			WHERE t1.[LaborTransactionId] = t2.[LaborTransactionId] AND
				t1.ReportingYear = t2.ReportingYear
		)
		
		SELECT ''Completed adding '' + CONVERT(varchar(10), @NewRecordsCount) + '' new records for FFY ' + CONVERT(char(4), @FiscalYear )+ '.'' AS [Message:]

		--DROP TABLE [dbo].[' + @TableName + ']

		SET NOCOUNT OFF; 
	END
	ELSE
	BEGIN
		SET NOCOUNT ON; 

		SELECT ''There were no new records to be added for FFY ' + CONVERT(char(4), @FiscalYear )+ '.'' AS [Message:]

		--DROP TABLE [dbo].[' + @TableName + ']

		SET NOCOUNT OFF; 
	END
'
	IF @IsDebug = 1 
	BEGIN
		SET NOCOUNT ON; 
		PRINT @TSQL
		SET NOCOUNT OFF;
	END
	ELSE 
		EXEC(@TSQL)

	SET NOCOUNT ON;
    
END