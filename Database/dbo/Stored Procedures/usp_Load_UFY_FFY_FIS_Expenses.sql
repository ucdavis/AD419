-- =============================================
-- Author:		Ken Taylor
-- Create date: August 8, 2016
-- Description:	Load the UFY_FFY_FIS_Expenses table
-- Note that this does not include expenses for UCD 204 accounts that are outside of our ARCs or orgs.
-- That requires a second step. 
-- Usage:
/*
	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_Load_UFY_FFY_FIS_Expenses]
			@FiscalYear = 2016,
			@IsDebug = 1

	SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	20160809 by kjt: Added SubAccount and PrincipalInvestigator
--	20160810 by kjt: Revised to use Account's PI name as BalanceSummaryV's PI Name was not unique for the same account.
--	20160810 by kjt: Added update of Org and OrgR where OrgR was null due to Org changes during fiscal year.
--  20160810 by kjt: Revised to use new table DaFIS_AccountsByARC
--  20160818 by kjt: Revised to use INNER JOIN FISDataMart.dbo.ARCCodes,
--	20170110 by kjt: Removed section that update blank Orgs and OrgRs as there should no longer be none,
--	  since we're using the same join in the INSERT/SELECT statement as was in the UPDATE statement.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Load_UFY_FFY_FIS_Expenses] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @FiscalYear int = 2016
	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	--DECLARE @ArcCodes TABLE (Chart varchar(2), Account varchar(7), ArcCode varchar(6), OpFundNum varchar(5))
	--INSERT INTO @ArcCodes
	--SELECT CHART_NUM Chart, ACCT_NUM Account, ANNUAL_REPORT_CODE AnnualReportCode, OP_FUND_NUM OpFundNum
	--FROM OPENQUERY(
	--FIS_DS, ''
	--	SELECT Chart_Num, ACCT_NUM, ANNUAL_REPORT_CODE, OP_FUND_NUM FROM FINANCE.ORGANIZATION_ACCOUNT
	--	WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''''--'''' 
	--''
	--) 
	--INNER JOIN FISDataMart.dbo.ARCCodes AC ON ANNUAL_REPORT_CODE = ARCCode

	TRUNCATE TABLE UFY_FFY_FIS_Expenses
	INSERT INTO UFY_FFY_FIS_Expenses (
		   [Chart]
		  ,[Account]
		  ,[SubAccount]
		  ,[PrincipalInvestigator]
		  ,[AnnualReportCode]
		  ,[OpFundNum]
		  ,[ConsolidationCode]
		  ,[TransDocType]
		  ,[OrgR]
		  ,[Org]
		  ,[Expenses]
	)
	select t1.Chart, accountNum Account, SubAccount,PrincipalInvestigatorName PrincipalInvestigator, ARCCode AnnualReportCode, AC.OpFundNum, ConsolidationCode, TransDocType, t5.OrgR, t4.Org,
		SUM(Expend) Expenses
	--INTO UFY_FFY_FIS_Expenses
	FROM FisDataMart.dbo.BalanceSummaryV t1
	INNER JOIN dbo.DaFIS_AccountsByARC AC ON t1.Chart = AC.Chart AND t1.accountNum = AC.Account 
	INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode 
	LEFT OUTER JOIN FISDataMart.Dbo.Accounts t4 ON t1.Chart = t4.Chart AND t1.AccountNum = t4.Account AND t4.Year = 9999 AND t4.Period = ''--''
	LEFT OUTER JOIN UFYOrganizationsOrgR_v t5 ON t1.Chart = t5.Chart AND t4.Org = t5.Org
	WHERE 
		((t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ' AND t1.FiscalPeriod BETWEEN ''04'' AND ''13'') OR 
		 (t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t1.FiscalPeriod BETWEEN ''01'' AND ''03''))
		AND TransBalanceType IN (''AC'')
		AND ConsolidationCode NOT IN (''INC0'', ''BLSH'', ''SB74'') 
		AND t1.Chart+AccountNum NOT IN (
			SELECT DISTINCT Chart+Account 
			FROM dbo.udf_ArcCodeAccountExclusionsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ')
		)  
		AND t1.HigherEdFunctionCode not like ''PROV''
	GROUP BY t1.Chart, AccountNum, SubAccount, PrincipalInvestigatorName, ARCCode, 
		AC.OpFundNum, ConsolidationCode, TransDocType, OrgR, t4.Org 
		, t4.Org, t5.OrgR HAVING SUM(Expend) <> 0
	ORDER By t1.Chart, AccountNum, SubAccount, PrincipalInvestigatorName, ARCCode, 
		AC.OpFundNum, ConsolidationCode, t4.Org, t5.OrgR
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

END