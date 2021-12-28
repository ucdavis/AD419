



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
			@FiscalYear = 2021,
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
--	20171002 by kjt: Added "SUB9" to the object exclusion list as per discussion with Shannon Tanguay 2017-10-02.
--	20171012 by kjt: Added population of new FiscalYear column.
--	20171020 by kjt: Revised population of Org and OrgR.  Removed joins for populating OrgR,
--		and replaced with update in order to maintain expenses' original OrgR, not an expired one
--		changed after the fact.  This was causing issues with expense OrgR to AD419 OrgR remapping.
--	20191121 by kjt: Revised to that GLJV documents would be removed from dataset for Sept 2019 (Period 03)
--		because of UC Path GLJV transactions showing up in both FIS, and Labor data for Sept 2019, but not
--		showing up in both for the previous eleven (11) months. 
-- Note: Make sure to uncomment standard date section, and comment sept date section.
--	20201118 by kjt Uncommented out date logic.
--	20201119 by kjt: Revised to exclude any GLJV labor expenses that have accounts present in the 
--		labor data.
--  20201125 by kjt: Removed logic that filtered out the GLJV labor data as these object codes are
--		used in downstream sproc for loading the PPS Data.  The filtering is now added to the consumers of
--		this table.
--	20211113 by kjt: Added object field so that we could include certain SUB6 expenses, i.e., Grad Student Rebates,
--		that will not ever be present in labor expenses.
--		
-- =============================================
CREATE PROCEDURE [dbo].[usp_Load_UFY_FFY_FIS_Expenses] 
	@FiscalYear int = 2021, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @FiscalYear int = 2020
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
		  ,[ObjectCode]
		  ,[TransDocType]
		  --,[OrgR]
		  ,[Org]
		  ,[Expenses]
		  ,[FiscalYear]
	)
	select t1.Chart, accountNum Account, SubAccount, PrincipalInvestigator, ARCCode AnnualReportCode, 
	AC.OpFundNum, ConsolidationCode, ObjectCode, TransDocType, --t5.OrgR, 
	OrgCode, SUM(Expend) Expenses, ' + CONVERT(varchar(4), @FiscalYear) + ' FiscalYear
	--INTO UFY_FFY_FIS_Expenses
	FROM FisDataMart.dbo.BalanceSummaryV t1
	INNER JOIN dbo.DaFIS_AccountsByARC AC ON t1.Chart = AC.Chart AND t1.accountNum = AC.Account 
	INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode 
	-- 20171020 by kjt:  Changed from left outer join to inner join to exclude superfluous accounts.
	--LEFT OUTER JOIN FISDataMart.Dbo.Accounts t4 ON t1.Chart = t4.Chart AND t1.AccountNum = t4.Account AND t4.Year = 9999 AND t4.Period = ''--''
	INNER JOIN FISDataMart.Dbo.Accounts t4 ON t1.Chart = t4.Chart AND t1.AccountNum = t4.Account AND t4.Year = 9999 AND t4.Period = ''--''
	-- 20171029 by kjt: Removed this join completely and we were getting some EXPR, DUMP, etc for the Orgs, etc.
	--LEFT OUTER JOIN UFYOrganizationsOrgR_v t5 ON t1.Chart = t5.Chart AND t4.Org = t5.Org
	WHERE 
	 --20191121 by kjt: Uncomment this data logic after FFY 2019-2020:
		((t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ' AND t1.FiscalPeriod BETWEEN ''04'' AND ''13'') OR 
		 (t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t1.FiscalPeriod BETWEEN ''01'' AND ''03''))
		-- Above date logic for typical FFY.

		---- 20191121 by kjt: Comment out this data logic after FFY 2019-2020:
		--(
		--	(
		--		(t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ' AND t1.FiscalPeriod BETWEEN ''04'' AND ''13'') OR 
		--		(t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t1.FiscalPeriod BETWEEN ''01'' AND ''02'')
		--	 ) OR 
		--	 (
		--		(
		--			t1.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND t1.FiscalPeriod = ''03''
		--		) AND
		--	     (
		--			t1.TransDocType != ''GLJV'' OR 
		--			(
		--				t1.TransDocType = ''GLJV'' AND 
		--				ConsolidationCode NOT IN (SELECT Obj_Consolidatn_Num FROM ConsolCodesForLaborTransactions)
		--			)
		--		)
		--	 )
		--)
		-- Above date logic only for FFY 2019-2020
		--
		AND TransBalanceType IN (''AC'')
		AND ConsolidationCode NOT IN (''INC0'', ''BLSH'', ''SB74'', ''SUB9'') 
		AND t1.Chart+AccountNum NOT IN (
			SELECT DISTINCT Chart+Account 
			FROM dbo.udf_ArcCodeAccountExclusionsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ')
		)  
		AND t1.HigherEdFunctionCode not like ''PROV''

	GROUP BY t1.Chart, AccountNum, SubAccount, PrincipalInvestigator, ARCCode, 
		AC.OpFundNum, ConsolidationCode, ObjectCode, TransDocType, OrgCode
		--OrgR, t4.Org , t4.Org, t5.OrgR 
		HAVING SUM(Expend) <> 0
	ORDER By t1.Chart, AccountNum, SubAccount, PrincipalInvestigator, ARCCode, 
		AC.OpFundNum, ConsolidationCode, ObjectCode, OrgCode --, t4.Org, t5.OrgR
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)

-- 20171020 by kjt Added logic to set any blank Org, plus set OrgR:
	SELECT @TSQL = '
	UPDATE UFY_FFY_FIS_Expenses
	SET Org = COALESCE(t2.Org, t3.Org) 
	FROM UFY_FFY_FIS_Expenses t1
	LEFT OUTER JOIN (
		SELECT DISTINCT Chart, Account, Org
		FROM FISDataMart.dbo.accounts t2  
		WHERE Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND (Period BETWEEN ''04'' and ''13'' OR Period = ''--'') 
		) t2 On t1.chart = t2.Chart and t1.Account = t2.Account
	LEFT OUTER JOIN (
		SELECT DISTINCT Chart, Account, Org
		FROM FISDataMart.dbo.accounts t2  
		WHERE Year = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND (Period BETWEEN ''01'' and ''03'' OR Period = ''--'') 
		) t3 On t1.chart = t3.Chart and t1.Account = t3.Account
	WHERE COALESCE(t2.Org, t3.Org)  IS NOT NULL AND t1.Org IS NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)


	SELECT @TSQL = '
	UPDATE UFY_FFY_FIS_Expenses
	SET OrgR = t2.OrgR
	FROM UFY_FFY_FIS_Expenses t1
	LEFT OUTER JOIN  (
		SELECT DISTINCT t1.Chart, t1.Org, COALESCE(t2.OrgR, t3.OrgR, t4.OrgR) OrgR 
		FROM [AD419].[dbo].UFY_FFY_FIS_Expenses t1 
		LEFT OUTER JOIN UFYOrganizationsOrgR_v t2 ON t1.chart = t2.Chart AND t1.Org = t2.Org
		LEFT OUTER JOIN FISDataMart.dbo.OrganizationsV  t3 ON t1.Chart = t3.Chart AND t1.Org = t3.Org 
			AND t3.Year = ' + CONVERT(varchar(4), @FiscalYear) + ' AND (t3.Period BETWEEN ''04'' and ''13'' OR t3.Period = ''--'') 
        LEFT OUTER JOIN FISDataMart.dbo.OrganizationsV  t4 ON t1.Chart = t4.Chart AND t1.Org = t4.Org 
			AND t4.Year = ' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND (t4.Period BETWEEN ''01'' AND ''03'' OR t4.Period = ''--'') 
	) t2 ON t1.Chart = t2.Chart AND t1.Org = t2.Org 
	WHERE t1.OrgR IS NULL AND t2.OrgR IS NOT NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END