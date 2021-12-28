


-- =============================================
-- Author:		Ken Taylor
-- Create date: October 13, 2020
-- Description:	Given a list of Chart-Account numbers, return the 
-- corresponding list of UC Path labor salary and fringe records.
--
-- Usage:
/*

USE [AD419]
GO

SET NOCOUNT ON

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_Get204LaborExpenseTransactions]
		@FiscalYear = 2020,
		@IsDebug = 1

SELECT	'Return Value' = @return_value

SET NOCOUNT OFF
GO

*/
-- Modifications:
--	20201026 by kjt: Revised to also include ERN_DERIVED_PERCENT data field.
--		Also revised to "M" or "B" for RateTypeCode based on PAY_FREQUENCY.
--	20201118 by kjt: Added logic to actually save the data to the PPS_ExpensesFor204Projects table.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_Get204LaborExpenseTransactions] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2020, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Generate the Chart-Account string to be used in the where clause:
	DECLARE @ChartAccountString varchar(MAX) = (SELECT [dbo].[udf_204ChartAccountString](2))

    -- Insert statements for procedure here
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
		CREATE TABLE [204LaborTransactionsTempTable] (
			[LaborTransactionId] [varchar](125) NOT NULL,
			[Chart] [varchar](2) NULL,
			[Account] [varchar](7) NULL,
			[SubAccount] [varchar](5) NULL,
			[Org] [varchar](4) NULL,
			[ObjConsol] [varchar](4) NULL,
			[Object] [varchar](4) NOT NULL,
			[FinanceDocTypeCd] [varchar](4) NULL,
			[DosCd] [varchar](3) NULL,
			[EmployeeID] [varchar](10) NULL,
			[EmployeeName] [varchar](100) NULL,
			[POSITION_NBR] [nvarchar](8) NULL,
			[EFFDT] [datetime2](7) NULL,
			[RateTypeCd] [varchar](3) NULL,
			[Hours] [numeric](18, 6) NOT NULL,
			[Amount] [money] NULL,
			[Payrate] [numeric](17, 4) NULL,
			[CalculatedFTE] [numeric](9, 6) NULL,
			[PayPeriodEndDate] [datetime2](7) NULL,
			[FringeBenefitSalaryCd] [varchar](1) NULL,
			[AnnualReportCode] [varchar](6) NULL,
			[ReportingYear] [int] NULL,
			[OrgId] varchar(4) NULL,
			[ERN_DERIVED_PERCENT] numeric(7,4) NULL
	 CONSTRAINT [PK_204LaborTransactionsTempTable] PRIMARY KEY CLUSTERED 
	(
		[LaborTransactionId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
'

	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
		EXEC(@TSQL)

	SELECT @TSQL = '
INSERT INTO [204LaborTransactionsTempTable] (LaborTransactionId, Chart, Account, SubAccount, Org, ObjConsol, Object, FinanceDocTypeCd, DOSCd, EmployeeID, EmployeeName, POSITION_NBR, EFFDT, RateTypeCd, Hours, Amount, Payrate, CalculatedFTE, PayPeriodEndDate, FringeBenefitSalaryCd, AnnualReportCode, ReportingYear, OrgId,ERN_DERIVED_PERCENT)
SELECT DISTINCT LaborTransactionId, Chart, Account, SubAccount, Org, ObjConsol, Object,	FinanceDocTypeCd, DOSCd, EmployeeID, EmployeeName, POSITION_NBR, EFFDT, RateTypeCd, Hours, Amount, Payrate, CalculatedFTE, PayPeriodEndDate, FringeBenefitSalaryCd, AnnualReportCode, ReportingYear, OrgId, ERN_DERIVED_PERCENT
FROM (
	SELECT  * 
	FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
		SELECT t1.JOURNAL_ID || ''''-'''' || 
				t1.JOURNAL_LINE || ''''-'''' || 
				t1.UC_ADDL_SEQ || ''''-'''' || 
				t1.POSITION_NBR "LaborTransactionId",
			OPERATING_UNIT "Chart",
			SUBSTR(DEPTID_CF,3, 7) "Account",
			CLASS_FLD "SubAccount",
			SUBSTR(UC_DEPTID_ROLLUP,3, 4) "Org",
			t2.FIN_CONS_OBJ_CD "ObjConsol",
			SUBSTR(ACCOUNT,3,4) Object,
			''''PAY'''' "FinanceDocTypeCd",
			ERNCD "DOSCd",
			t1.EMPLID "EmployeeID",
			'''''''' EmployeeName,
			t1.POSITION_NBR,
			t1.EFFDT,
			PAY_FREQUENCY AS "RateTypeCd",	
			Hours1 "Hours",
			MONETARY_AMOUNT "Amount",
			CASE WHEN Hours1 <> 0 THEN round(MONETARY_AMOUNT/Hours1, 3) ELSE 0 END "Payrate",
			CASE WHEN Hours1 <> 0 THEN ROUND(hours1/2088, 6) ELSE 0 END "CalculatedFTE",
			UC_EARN_END_DT "PayPeriodEndDate",
			''''S'''' "FringeBenefitSalaryCd",
			' + CONVERT(char(4), @FiscalYear) + ' "ReportingYear",
			UC_DRV_EFT_PCT "ERN_DERIVED_PERCENT"
		FROM CAES_HCMODS.PS_UC_LL_SAL_DTL_V t1
		INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
				SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
				t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
				t1.Fiscal_Year = t2.UNIV_FISCAL_YR 
		LEFT OUTER JOIN CAES_HCMODS.PS_PAYGROUP_TBL_V t3 ON
				t1.PAYGROUP = t3.PAYGROUP AND 
				t3.EFF_STATUS = ''''A'''' AND
				t3.EFFDT = (
					SELECT MAX(EFFDT)
					FROM CAES_HCMODS.PS_PAYGROUP_TBL_V t4
					WHERE t3.PAYGROUP = t4.PAYGROUP AND
						t3.EFF_STATUS = t4.EFF_STATUS AND
						t4.EFFDT <= CURRENT_DATE AND
						t4.DML_IND <> ''''D''''
					)
			WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
				(
					(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + ' AND t1.ACCOUNTING_PERIOD BETWEEN 4 AND 13) OR
					(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + ' AND t1.ACCOUNTING_PERIOD BETWEEN 1 AND 3) 
				) AND
				t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
				t1.DML_IND <> ''''D'''' AND
				SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''')  AND
				DEPTID_CF IN (' + @ChartAccountString + ') 	
'') t1
INNER JOIN (
	SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE "AnnualReportCode", ORG_ID "OrgId"
	FROM OPENQUERY([FIS_DS], ''
		SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID 
		FROM FINANCE.ORGANIZATION_ACCOUNT A
		WHERE A.FISCAL_YEAR = 9999 AND 
			A.FISCAL_PERIOD = ''''--'''' AND
			A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV'''' 
	'')
	) t2 ON t1.Chart = t2.CHART_NUM AND t1.Account = t2.ACCT_NUM
) tOuter
'
	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
INSERT INTO [204LaborTransactionsTempTable] (LaborTransactionId, Chart, Account, SubAccount, Org, ObjConsol, Object, FinanceDocTypeCd, DOSCd, EmployeeID, EmployeeName, POSITION_NBR, EFFDT, RateTypeCd, Hours, Amount, Payrate, CalculatedFTE, PayPeriodEndDate, FringeBenefitSalaryCd, AnnualReportCode, ReportingYear, OrgId, ERN_DERIVED_PERCENT)
SELECT DISTINCT LaborTransactionId, Chart, Account, SubAccount, Org, ObjConsol, Object,	FinanceDocTypeCd, DOSCd, EmployeeID, EmployeeName, POSITION_NBR, EFFDT, RateTypeCd, Hours, Amount, Payrate, CalculatedFTE, PayPeriodEndDate, FringeBenefitSalaryCd, AnnualReportCode, ReportingYear, OrgId, ERN_DERIVED_PERCENT
FROM (
  SELECT * 
  FROM OPENQUERY ([FIS_BISTG_PRD (CAES_HCMODS_APPUSER)],''
	SELECT 
		t1.JOURNAL_ID || ''''-'''' || 
		t1.JOURNAL_LINE || ''''-'''' || 
		t1.UC_ADDL_SEQ || ''''-'''' || 
		t1.POSITION_NBR "LaborTransactionId",
		t1.OPERATING_UNIT "Chart",
		SUBSTR(DEPTID_CF, 3, 7) "Account",
		CLASS_FLD "SubAccount",
		SUBSTR(UC_DEPTID_ROLLUP, 3, 4) "Org",
		t2.FIN_CONS_OBJ_CD  "ObjConsol",
		SUBSTR(ACCOUNT,4, 4) "Object",
		''''PAY'''' FinanceDocTypeCd,
		''''XXX'''' "DOSCd",
		t1.EMPLID "EmployeeID",
		'''''''' EmployeeName,
		t1.POSITION_NBR,
		t1.EFFDT,
		PAY_FREQUENCY AS "RateTypeCd",	
		0 "Hours",
		MONETARY_AMOUNT "Amount",
		0 "Payrate",
		0 "CalculatedFTE",
		UC_EARN_END_DT "PayPeriodEndDate",
		''''F'''' "FringeBenefitSalaryCd",
		' + CONVERT(char(4), @FiscalYear) + ' "ReportingYear",
		0 "ERN_DERIVED_PERCENT"
	FROM CAES_HCMODS.PS_UC_LL_FRNG_DTL_V t1
	INNER JOIN CAES_HCMODS.UCD_OBJECT_CODES_V t2 ON 
		SUBSTR(t1.ACCOUNT,3,4) = t2.FIN_OBJECT_CD AND 
		t1.OPERATING_UNIT = t2.FIN_COA_CD AND 
		t1.Fiscal_Year = t2.UNIV_FISCAL_YR 

	LEFT OUTER JOIN CAES_HCMODS.PS_PAYGROUP_TBL_V t3 ON
			t1.PAYGROUP = t3.PAYGROUP AND 
			t3.EFF_STATUS = ''''A'''' AND
			t3.COMPANY = ''''UCS'''' AND
			t3.EFFDT = (
				SELECT MAX(EFFDT)
				FROM CAES_HCMODS.PS_PAYGROUP_TBL_V t4
				WHERE t3.PAYGROUP = t4.PAYGROUP AND
					t3.COMPANY = t4.COMPANY AND
					t3.EFF_STATUS = t4.EFF_STATUS AND
					t4.EFFDT <= CURRENT_DATE AND
					t4.DML_IND <> ''''D''''
			)			

	WHERE OPERATING_UNIT IN (''''3'''',''''L'''') AND
		(
		(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear) + ' AND t1.ACCOUNTING_PERIOD BETWEEN 4 AND 13) OR
		(t1.FISCAL_YEAR = ' + CONVERT(char(4), @FiscalYear + 1) + ' AND t1.ACCOUNTING_PERIOD BETWEEN 1 AND 3) 
		) AND
		t1.BUSINESS_UNIT IN (''''DVCMP'''',''''UCANR'''') AND
		t1.DML_IND <> ''''D'''' AND
		SUBSTR(t1.ACCOUNT,3,4) NOT IN (''''INC0'''', ''''BLSH'''', ''''SB74'''', ''''SUB9'''') AND
		DEPTID_CF IN (' + @ChartAccountString + ') 
'') t1
INNER JOIN 
	(
	SELECT CHART_NUM, ACCT_NUM, ANNUAL_REPORT_CODE "AnnualReportCode", ORG_ID "OrgId"
	FROM OPENQUERY([FIS_DS], ''
		SELECT A.CHART_NUM, A.ACCT_NUM, A.ANNUAL_REPORT_CODE, A.ORG_ID 
		FROM FINANCE.ORGANIZATION_ACCOUNT A
		WHERE A.FISCAL_YEAR = 9999 AND 
			A.FISCAL_PERIOD = ''''--'''' AND
			A.HIGHER_ED_FUNC_CODE NOT LIKE ''''PROV'''' 
	'') 
	) t2 ON t1.Chart = t2.CHART_NUM AND t1.Account = t2.ACCT_NUM
) tOuter
'
	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
		EXEC(@TSQL)

	
	SELECT @TSQL = '
	INSERT INTO PPS_ExpensesFor204Projects
	SELECT * 
	FROM [204LaborTransactionsTempTable]
	ORDER BY LaborTransactionId

	-- Housekeeping when we''re through returning results:

	--TRUNCATE TABLE [204LaborTransactionsTempTable]
	--DROP TABLE [204LaborTransactionsTempTable]
'

	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
		EXEC(@TSQL)
	
END