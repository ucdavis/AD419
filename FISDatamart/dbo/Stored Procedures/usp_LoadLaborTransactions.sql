
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 1st, 2016
-- Description:	Merges the LaborTransactions table so we can later use it for figuring out
-- the labor portion of the expenses
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_LoadLaborTransactions]
		@FiscalYear = 2019,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications
--	2018-05-14 by kjt: Added Labor Transactions to FIS DataMart since it is now also used for
-- Animal Health queries, plus renamed table to LaborTransactions Vs. AnotherLaborTransactions.
--	2019-12-13 by kj: Revised sproc name and updated logic to use same as Reload Labor Transactions
--		SQL script.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadLaborTransactions] 
	@FiscalYear int = 2019, 
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
INSERT INTO [dbo].[LaborTransactions] (
	   [Year]
      ,[Period]
      ,LaborTransactionId
	  ,[Chart]
      ,[Account]
      ,[SubAccount]
      ,[Org]
      ,[ObjConsol]
      ,[Object]
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
      ,[ExcludedByOrg]
      ,[ReportingYear]
	 )
SELECT 
	   [Year]
	  ,[Period]
	  ,[LaborTransactionId]
	  ,[Chart]
      ,[Account]
      ,[SubAccount]
      ,[Org]
      ,[ObjConsol]
	  ,[Object]
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
      ,[ExcludedByOrg]
	  ,[ReportingYear]
	 
FROM OPENQUERY(FIS_DS, ''
SELECT 
	UNIV_FISCAL_YR "Year",
	UNIV_FISCAL_PRD_CD "Period",
	LABOR_TRANSACTION_ID "LaborTransactionId",
	FIN_COA_CD "Chart", 
	ACCOUNT_NBR "Account",
	SUB_ACCT_NBR "SubAccount",
	ORG_CD "Org", 
	FIN_CONS_OBJ_CD "ObjConsol",
	FIN_OBJECT_CD "Object",
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
	' + CONVERT(varchar(4), @FiscalYear) +  ' "ReportingYear"
	FROM 
	FINANCE.LABOR_TRANSACTIONS LT
	INNER JOIN FINANCE.ORGANIZATION_ACCOUNT A ON 
			LT.FIN_COA_CD = A.CHART_NUM AND
			LT.ACCOUNT_NBR = A.ACCT_NUM AND 
			A.FISCAL_YEAR = 9999 AND
			A.FISCAL_PERIOD = ''''--'''' AND 
			A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV''''
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
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear) +  ' AND UNIV_FISCAL_PRD_CD BETWEEN ''''04'''' AND ''''13'''') OR 
		(UNIV_FISCAL_YR = ' + CONVERT(varchar(4), @FiscalYear + 1) +  ' AND UNIV_FISCAL_PRD_CD BETWEEN ''''01'''' AND ''''03'''')
	) AND 
	FIN_BALANCE_TYP_CD = ''''AC'''' AND 
	FS_ORIGIN_CD NOT LIKE ''''PL'''' AND
	FIN_CONS_OBJ_CD NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') 

GROUP BY 
	UNIV_FISCAL_YR,
	UNIV_FISCAL_PRD_CD,
	LABOR_TRANSACTION_ID,
	FIN_COA_CD, 
	ACCOUNT_NBR,
	SUB_ACCT_NBR,
	ORG_CD,
	FIN_CONS_OBJ_CD,
	FIN_OBJECT_CD,
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
	SUM(TRN_LDGR_ENTR_AMT) <> 0'') AS source
	WHERE NOT EXISTS (
		SELECT Year, LaborTransactionId FROM LaborTransactions t1 WHERE t1.Year = source.Year AND t1.LaborTransactionId = source.LaborTransactionId
	)
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
UPDATE [dbo].[LaborTransactions]
SET ExcludedByAccount = 0
'

	SELECT @TSQL += '
UPDATE  [dbo].[LaborTransactions] 
SET ExcludedByAccount = 1
FROM [dbo].[LaborTransactions] t1
INNER JOIN (
	SELECT DISTINCT Chart, Account 
	FROM[dbo].ArcCodeAccountExclusions
	) t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
UPDATE [dbo].[LaborTransactions]
SET ExcludedByObjConsol = 1
'
	SELECT @TSQL += '
UPDATE  [dbo].[LaborTransactions] 
SET ExcludedByObjConsol = 0
FROM [dbo].[LaborTransactions] t1
INNER JOIN [dbo].ConsolCodesForLaborTransactions t2 ON t1.ObjConsol = t2.Obj_Consolidatn_Num 
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)

	SELECT @TSQL = '
UPDATE [dbo].[LaborTransactions]
SET ExcludedByARC = 1
'

	SELECT @TSQL += '
UPDATE [dbo].[LaborTransactions]
SET ExcludedByARC = 0 
FROM [dbo].[LaborTransactions] t1
INNER JOIN [dbo].[ARCCodes] t2 ON t1.AnnualReportCode = t2.ARCCode
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)


	SELECT @TSQL = '
UPDATE [dbo].[LaborTransactions] 
SET EmployeeName = FullName
FROM [dbo].[LaborTransactions]  t1
INNER JOIN [PPSDataMart].[dbo].[Persons] t2 ON t1.EmployeeId = t2. EmployeeId
WHERE t1.EmployeeName IS NULL
'

	SELECT @TSQL += '
-- This should return zero (0) rows.
SELECT ''The following result set should return zero (0) rows:'' AS Message
SELECT * FROM [dbo].[LaborTransactions]
WHERE EmployeeName IS NULL AND ExcludedByARC = 0 AND ExcludedByOrg = 0 
'

	IF @IsDebug = 1  
		PRINT @TSQL
	ELSE 
		EXEC(@TSQL)
END