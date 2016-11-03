-- =============================================
-- Author:		Ken Taylor
-- Create date: August 1st, 2016
-- Description:	Loads the AnotherLaborTransactions table so we can later use it for figuring out
-- the labor portion of the expenses
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadAnotherLaborTransactions]
		@FiscalYear = 2016,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--	2016-08028 by kjt: Added a message prior to the final select statement.
--	2015-09-14 by kjt: Revised to include all records, and set the ExcludedByObjConsol flag.
--	2016-10-31 by kjt: Added statement to update the new ReportingYear column so that we
--	can more easily tell if the table needs to be reloaded as the existing check was giving a false negative
--	due to future and retroactive pay, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadAnotherLaborTransactions] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	DECLARE @ConsolidationCodes varchar(MAX) = ''
	SET @ConsolidationCodes = (SELECT dbo.udf_QuotedConsolCodesForLaborTransactionsString(2))

	SELECT @TSQL = '
TRUNCATE TABLE [AD419].[dbo].[AnotherLaborTransactions]

INSERT INTO [AD419].[dbo].[AnotherLaborTransactions] (
	   [Chart]
      ,[Account]
      ,[SubAccount]
      ,[Org]
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      ,[EmployeeID]
      ,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[Amount]
      ,[PayPeriodEndDate]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
      --,[ExcludedByARC]
      ,[ExcludedByOrg]
      --,[ExcludedByAccount]
	  --,[ExcludedByObjConsol]
	  ,[ReportingYear]
)
SELECT [Chart]
      ,[Account]
      ,[SubAccount]
      ,[Org]
      ,[ObjConsol]
      ,[FinanceDocTypeCd]
      ,[DosCd]
      ,[EmployeeID]
      ,[EmployeeName]
      ,[TitleCd]
      ,[RateTypeCd]
      ,[Payrate]
      ,[Amount]
      ,[PayPeriodEndDate]
      ,[FringeBenefitSalaryCd]
      ,[AnnualReportCode]
      --,[ExcludedByARC]
      ,[ExcludedByOrg]
      --,[ExcludedByAccount]
	  --,[ExcludedByObjConsol]
	  ,[ReportingYear]
FROM OPENQUERY(FIS_DS, ''
SELECT 
	FIN_COA_CD "Chart", 
	ACCOUNT_NBR "Account",
	SUB_ACCT_NBR "SubAccount",
	ORG_CD "Org", 
	FIN_CONS_OBJ_CD "ObjConsol",
	FDOC_TYP_CD "FinanceDocTypeCd",
	ERNCD "DosCd",
	EMPLID "EmployeeID", 
	PERSON_NAME "EmployeeName",
	PPS_TITLE_CD "TitleCd",
	RATE_TYPE_CD "RateTypeCd",
    DIST_PAY_RATE "PayRate",
	TO_NUMBER(SUM(TRN_LDGR_ENTR_AMT), 9999999999.99)  "Amount",
	PAY_PERIOD_END_DT "PayPeriodEndDate",
    FINOBJ_FRNGSLRY_CD "FringeBenefitSalaryCd",
	A.ANNUAL_REPORT_CODE "AnnualReportCode",
	CASE WHEN O.ORG_ID_LEVEL_4 IN (''''AAES'''', ''''BIOS'''') THEN 0 ELSE 1 END "ExcludedByOrg",
	--CASE WHEN FIN_CONS_OBJ_CD IN (' + @ConsolidationCodes + ') THEN 0 ELSE 1 END "ExcludedByObjConsol",
	' + CONVERT(varchar(4), @FiscalYear) + ' "ReportingYear"
	FROM 
	FINANCE.LABOR_TRANSACTIONS LT
	INNER JOIN FINANCE.ORGANIZATION_ACCOUNT A ON 
			LT.FIN_COA_CD = A.CHART_NUM AND
			LT.ACCOUNT_NBR = A.ACCT_NUM AND 
			A.FISCAL_YEAR = 9999 AND
			A.FISCAL_PERIOD = ''''--''''
	INNER JOIN ORGANIZATION_HIERARCHY O ON 
		A.CHART_NUM = O.CHART_NUM AND
		A.ORG_ID = O.ORG_ID AND
		A.FISCAL_YEAR = O.FISCAL_YEAR AND
		A.FISCAL_PERIOD = O.FISCAL_PERIOD
	LEFT OUTER JOIN (
		SELECT EMPLOYEE_ID, MAX(PERSON_NAME) PERSON_NAME
		FROM FINANCE.UCD_PERSON 
		GROUP BY EMPLOYEE_ID
	) P ON EMPLID = EMPLOYEE_ID
WHERE  
	(
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear) + ' AND UNIV_FISCAL_PRD_CD BETWEEN ''''04'''' AND ''''13'''') OR 
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear + 1)+ ' AND UNIV_FISCAL_PRD_CD BETWEEN ''''01'''' AND ''''03'''')
	) AND 
	FIN_BALANCE_TYP_CD = ''''AC'''' AND 
	FS_ORIGIN_CD NOT LIKE ''''PL''''
GROUP BY 
	FIN_COA_CD, 
	ACCOUNT_NBR,
	SUB_ACCT_NBR,
	ORG_CD,
	FIN_CONS_OBJ_CD,
	FDOC_TYP_CD,
	ERNCD,
	EMPLID,
	PERSON_NAME,
	PPS_TITLE_CD,
	RATE_TYPE_CD,
	DIST_PAY_RATE,
	FINOBJ_FRNGSLRY_CD,
	A.ANNUAL_REPORT_CODE,
	O.ORG_ID_LEVEL_4,
	PAY_PERIOD_END_DT
HAVING 
	SUM(TRN_LDGR_ENTR_AMT) <> 0'') t1
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

 /*
 (1,937,658 row(s) affected)
 04:43 using where clause
 */

 /*
 (1,937,658 row(s) affected)
 05:13 using INNER JOIN
 */

 /*
 (1,937,658 row(s) affected)
 04:40 Using quoted string within OPENQUERY where clause.
 */

	SELECT @TSQL = '
UPDATE [AD419].[dbo].[AnotherLaborTransactions]
SET ExcludedByAccount = 0
'

	SELECT @TSQL += '
UPDATE  [AD419].[dbo].[AnotherLaborTransactions] 
SET ExcludedByAccount = 1
FROM [AD419].[dbo].[AnotherLaborTransactions] t1
INNER JOIN [AD419].[dbo].ArcCodeAccountExclusions t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.Year = ' + CONVERT(varchar(4), @FiscalYear) + '
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
UPDATE [AD419].[dbo].[AnotherLaborTransactions]
SET ExcludedByObjConsol = 1
'
	SELECT @TSQL += '
UPDATE  [AD419].[dbo].[AnotherLaborTransactions] 
SET ExcludedByObjConsol = 0
FROM [AD419].[dbo].[AnotherLaborTransactions] t1
INNER JOIN [AD419].[dbo].ConsolCodesForLaborTransactions t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num 
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	SELECT @TSQL = '
UPDATE [AD419].[dbo].[AnotherLaborTransactions]
SET ExcludedByARC = 1
'

	SELECT @TSQL += '
UPDATE [AD419].[dbo].[AnotherLaborTransactions]
SET ExcludedByARC = 0 
FROM [AD419].[dbo].[AnotherLaborTransactions] t1
INNER JOIN FISDataMart.dbo.ARCCodes t2 ON t1.AnnualReportCode = t2.ARCCode
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
UPDATE [AD419].[dbo].[AnotherLaborTransactions] 
SET EmployeeName = FullName
FROM [AD419].[dbo].[AnotherLaborTransactions]  t1
INNER JOIN PPSDataMart.DBO.Persons t2 ON t1.EmployeeId = t2. EmployeeId
WHERE t1.EmployeeName IS NULL
'

	SELECT @TSQL += '
-- This should return zero (0) rows.
SELECT ''This should return zero (0) rows:'' AS Message
SELECT * FROM AnotherLaborTransactions 
WHERE EmployeeName IS NULL AND ExcludedByARC = 0 AND ExcludedByOrg = 0 
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END