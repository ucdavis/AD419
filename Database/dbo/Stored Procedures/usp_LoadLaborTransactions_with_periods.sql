-- =============================================
-- Author:		Ken Taylor
-- Create date: November 8, 2012
-- Description:	Load the LaborTransactions so it can later be used as a datasource for Raw PPS Expenses.
--				  since TOE is no longer available because labor related info in not stored in FIS
--				    Labor_Transactions table.
-- Modifications:
--	2012-11-16 by kjt: Revised to use an LEFT OUTER JOIN with FINANCE.UCD_PERSON as 84 people were
--		missing and filtered out over $800,000 in expenses if I used an INNER JOIN.
-- However, SPROC usp_UpdateLaborTransactionsMissingEmployeeNames will need to be run after running this script.
-- 2013-11-13 by kjt: Revised to select MAX(PERSON_NAME) FROM FINANCE.UCD_PERSON as there are multiple 
--	names for the same Employee ID!
-- 2015-02-24 by kjt: Removed [AD419] specific database references so sproc could be used on other databases
-- such as AD419_2014, etc.
-- 2015-11-05 by kjt: Removed pay_period_end_date filte as per Shammon because not all FY labor expenses were being returned.
-- 2015-11-12 by kjt: Added fields for fiscal year, fiscal period, payroll date fiscal year, and payroll date fiscal period.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadLaborTransactions_with_periods] 
	@FiscalYear int = 2012, -- AD419 fiscal reporting year in question.
	@IsDebug bit = 0 -- Set to 1 to not execute, but return generated SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;
	DECLARE @ARCCodesString varchar(MAX) = (SELECT dbo.udf_ArcCodesString(DEFAULT))
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
TRUNCATE TABLE [dbo].[LaborTransactions]
	'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

SELECT @TSQL = '
INSERT INTO [dbo].[LaborTransactions] (
	   [TOE_Name]
      ,[EID]
      ,[Org]
      ,[Account]
      ,[SubAcct]
      ,[ObjConsol]
      ,[Object]
      ,[TitleCd]
      ,[FinanceDocTypeCd]
	  ,[DosCd]
      ,[PayPeriodEndDate]
      ,[RateTypeCd]
      ,[PayRate]
      ,[Amount]
      ,[FringeBenefitSalaryCd],
	  [Year],
	  [Period],
	  [PayrollDateYear],
	  [PayrollDatePeriod])
SELECT 
	   [TOE_Name]
      ,[EID]
      ,[Org]
      ,[Account]
      ,[SubAcct]
      ,[ObjConsol]
      ,[Object]
      ,[TitleCd]
      ,[FinanceDocTypeCd]
	  ,[DosCd]
      ,[PayPeriodEndDate]
      ,[RateTypeCd]
      ,[PayRate]
      ,[Amount]
      ,[FringeBenefitSalaryCd]
	  ,[Year],
	  [Period],
	  [PayrollDateYear],
	  [PayrollDatePeriod]
FROM OPENQUERY(FIS_DS, ''
	SELECT  
	   PERSON_NAME TOE_Name
	  ,EMPLID EID
      ,ORG_CD Org
      ,ACCOUNT_NBR Account
      ,SUB_ACCT_NBR SubAcct
      ,FIN_CONS_OBJ_CD ObjConsol
      ,FIN_OBJECT_CD Object
	  ,PPS_TITLE_CD TitleCd
	  ,FDOC_TYP_CD FinanceDocTypeCd
	  ,ERNCD DosCd
	  ,PAY_PERIOD_END_DT PayPeriodEndDate
	  ,RATE_TYPE_CD RateTypeCd
      ,DIST_PAY_RATE PayRate
      ,SUM(TRN_LDGR_ENTR_AMT) Amount
      ,FINOBJ_FRNGSLRY_CD FringeBenefitSalaryCd,
	  univ_fiscal_yr Year,
	  univ_fiscal_prd_cd Period,
	  pyrl_dt_fscl_yr PayrollDateYear,
	  pyrl_dt_fsclprd_cd PayrollDatePeriod
	FROM
		FINANCE.LABOR_TRANSACTIONS LT
	INNER JOIN 
		FINANCE.ORGANIZATION_ACCOUNT A ON 
			LT.ACCOUNT_NBR = A.ACCT_NUM AND 
			LT.UNIV_FISCAL_YR = A.FISCAL_YEAR AND
			LT.FIN_COA_CD = A.CHART_NUM AND 
			A.FISCAL_PERIOD = ''''--''''
	LEFT OUTER JOIN (
		SELECT EMPLOYEE_ID, MAX(PERSON_NAME) PERSON_NAME
		FROM FINANCE.UCD_PERSON 
		GROUP BY EMPLOYEE_ID
	) P ON EMPLID = EMPLOYEE_ID
	WHERE 
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear) + ') OR 
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND UNIV_FISCAL_PRD_CD BETWEEN ''''01'''' AND ''''03'''')
		AND FIN_COA_CD = ''''3''''
		--AND PAY_PERIOD_END_DT >= TO_DATE(''''' + CONVERT(varchar(4), @FiscalYear -1) +'.07.01'''', ''''yyyy.mm.dd'''')
		AND FS_ORIGIN_CD NOT LIKE ''''PL''''
		AND A.ANNUAL_REPORT_CODE IN (' + @ARCCodesString + ')
	GROUP BY
		PERSON_NAME,
		EMPLID,
		ORG_CD,
		ACCOUNT_NBR,
		SUB_ACCT_NBR,
		FIN_CONS_OBJ_CD,
		FIN_OBJECT_CD,
		PPS_TITLE_CD,
		FDOC_TYP_CD,
	    ERNCD,
		univ_fiscal_yr,
	  univ_fiscal_prd_cd,
	  pyrl_dt_fscl_yr,
	  pyrl_dt_fsclprd_cd,
		PAY_PERIOD_END_DT,
		RATE_TYPE_CD,
		DIST_PAY_RATE,
		FINOBJ_FRNGSLRY_CD,
		TRN_LDGR_ENTR_AMT
'') LT
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END