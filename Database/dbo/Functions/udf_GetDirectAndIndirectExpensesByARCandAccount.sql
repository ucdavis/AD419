﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: June 8, 2016
-- Description:	Return a list of Direct and Indirect FFY expenses via ARC code by Chart and Account.
--
-- NOTE: The DaFIS_AccountsByARC table must be loaded prior to running this procedure!
--
-- Usage: 
/*
	SELECT * FROM udf_GetDirectAndIndirectExpensesByARCandAccount(2015, 0) -- FFY

	SELECT * FROM udf_GetDirectAndIndirectExpensesByARCandAccount(2015, 1) -- SFY

-- This function is also used to populate the FFY_Expenses_ByARC table:
	TRUNCATE TABLE FFY_ExpensesByARC
	INSERT INTO FFY_ExpensesByARC
	SELECT * FROM dbo.udf_GetDirectAndIndirectExpensesByARCandAccount(2015, 0)
*/
-- Modifications:
-- 20160808 by kjt: Added exclusion of expenses with a higher ed function code of PROV.
-- 20160817 by kjt: Replaced in-memory ARC codes table with DaFIS_AccountsByARC database table.
-- 20160818 by kjt: Revised query so that CA&ES ARC filtering is done in INNER JOIN, and not 
--		beforehand in DaFIS_AccountByARC.
-- 20160921 by kjt: Revised to allow passing of parameter for SFY so same procedure can be used
-- for both FFY and SFY Expenses by ARC.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetDirectAndIndirectExpensesByARCandAccount] 
(
	@FiscalYear int,
	@UseStateFiscalYear bit = 0 --FFY (default)
)
RETURNS 
@DirectAndIndirectExpenses TABLE 
(
	AnnualReportCode varchar(20), 
	Chart varchar(2),
	Account varchar(7),
	ConsolidationCode varchar(4),
	DirectTotal money,
	IndirectTotal money,
	Total money
)
AS
BEGIN
	-- The following was replaced by using the data present in DaFIS_AccountByARC table.

	--DECLARE @ArcCodes TABLE (Chart varchar(2), Account varchar(7), ArcCode varchar(6), OpFundNum varchar(5))
	--INSERT INTO @ArcCodes
	--SELECT CHART_NUM Chart, ACCT_NUM Account, ANNUAL_REPORT_CODE AnnualReportCode, OP_FUND_NUM OpFundNum
	--FROM OPENQUERY(
	--FIS_DS, '
	--	SELECT Chart_Num, ACCT_NUM, ANNUAL_REPORT_CODE, OP_FUND_NUM FROM FINANCE.ORGANIZATION_ACCOUNT
	--	WHERE FISCAL_YEAR = 9999 AND FISCAL_PERIOD = ''--'' 
	--'
	--) 
	--INNER JOIN FISDataMart.dbo.ARCCodes AC ON ANNUAL_REPORT_CODE = ARCCode



	-- Get all the direct expenses with sums <> 0
	IF @UseStateFiscalYear = 0
	BEGIN
		INSERT INTO @DirectAndIndirectExpenses
		select 
		ARCCode AnnualReportCode,
		e.Chart,
		AccountNum Account,
		ConsolidationCode,
		sum(Expend) DirectTotal,
		0 AS IndirectTotal,
		0 AS Total
		from 
			FISDatamart.dbo.BalanceSummaryV e inner join 
			DaFIS_AccountsByARC --@ArcCodes
			AC  ON e.Chart = AC.Chart AND e.accountNum = AC.Account  
			INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode
		where 
			((e.FiscalYear = @FiscalYear AND e.FiscalPeriod BETWEEN '04' AND '13') OR 
				 (e.FiscalYear = @FiscalYear + 1 AND e.FiscalPeriod BETWEEN '01' AND '03'))
			AND TransBalanceType IN ('AC')
			AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') AND ConsolidationCode NOT LIKE 'INDR' AND  TransBalanceType = 'AC' 
			AND e.HigherEdFunctionCode not like 'PROV'
			and e.Chart+AccountNum NOT IN (
				SELECT DISTINCT Chart+Account 
				FROM AD419.dbo.ArcCodeAccountExclusions
				WHERE Year = @FiscalYear
			) 
		group by 
			ARCCode , e.Chart, e.AccountNum, e.ConsolidationCode
		having sum(Expend) <> 0
		order by 
			ARCCode , e.Chart, e.AccountNum
	END
	ELSE
	BEGIN
		INSERT INTO @DirectAndIndirectExpenses
		select 
		ARCCode AnnualReportCode,
		e.Chart,
		AccountNum Account,
		ConsolidationCode,
		sum(Expend) DirectTotal,
		0 AS IndirectTotal,
		0 AS Total
		from 
			FISDatamart.dbo.BalanceSummaryV e inner join 
			DaFIS_AccountsByARC --@ArcCodes
			AC  ON e.Chart = AC.Chart AND e.accountNum = AC.Account  
			INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode
		where 
			e.FiscalYear = @FiscalYear
			AND TransBalanceType IN ('AC')
			AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') AND ConsolidationCode NOT LIKE 'INDR' AND  TransBalanceType = 'AC' 
			AND e.HigherEdFunctionCode not like 'PROV'
			and e.Chart+AccountNum NOT IN (
				SELECT DISTINCT Chart+Account 
				FROM AD419.dbo.ArcCodeAccountExclusions
				WHERE Year = @FiscalYear
			) 
		group by 
			ARCCode , e.Chart, e.AccountNum, e.ConsolidationCode
		having sum(Expend) <> 0
		order by 
			ARCCode , e.Chart, e.AccountNum
	END

	-- Prepare to get all the indirect expenses separately:
	DECLARE @IndirectExpenses TABLE (
		AnnualReportCode varchar(20), 
		Chart varchar(2),
		Account varchar(7),
		ConsolidationCode varchar(4),
		DirectTotal money,
		IndirectTotal money,
		Total money
	)

	-- Get all the indirect expenses with expenses <> 0 
	IF @UseStateFiscalYear = 0
	BEGIN
		INSERT INTO @IndirectExpenses 
		select 
			ARCCode AnnualReportCode,
			e.Chart,
			AccountNum Account,
			ConsolidationCode,
			0 AS DirectTotal,
			sum(Expend) IndirectTotal,
			0 AS Total 
		from 
			FISDatamart.dbo.BalanceSummaryV e
			INNER JOIN DaFIS_AccountsByARC AC ON e.Chart = AC.Chart AND e.accountNum = AC.Account 
			INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode
		where 
			((e.FiscalYear = @FiscalYear AND e.FiscalPeriod BETWEEN '04' AND '13') OR 
			 (e.FiscalYear = @FiscalYear + 1 AND e.FiscalPeriod BETWEEN '01' AND '03'))
			AND TransBalanceType IN ('AC')
			AND ConsolidationCode  LIKE 'INDR' AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') 
			AND e.HigherEdFunctionCode not like 'PROV'
			and e.Chart+AccountNum NOT IN (
				SELECT DISTINCT Chart+Account 
				FROM AD419.dbo.ArcCodeAccountExclusions
				WHERE Year = @FiscalYear
			) 
		group by 
			ARCCode, e.Chart, e.AccountNum, e.ConsolidationCode
		having sum(Expend) <> 0
	END
	ELSE
	BEGIN
	INSERT INTO @IndirectExpenses 
		select 
			ARCCode AnnualReportCode,
			e.Chart,
			AccountNum Account,
			ConsolidationCode,
			0 AS DirectTotal,
			sum(Expend) IndirectTotal,
			0 AS Total 
		from 
			FISDatamart.dbo.BalanceSummaryV e
			INNER JOIN DaFIS_AccountsByARC AC ON e.Chart = AC.Chart AND e.accountNum = AC.Account 
			INNER JOIN FISDataMart.dbo.ARCCodes Arc ON AC.AnnualReportCode = ARCCode
		where 
			e.FiscalYear = @FiscalYear
			AND TransBalanceType IN ('AC')
			AND ConsolidationCode  LIKE 'INDR' AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') 
			AND e.HigherEdFunctionCode not like 'PROV'
			and e.Chart+AccountNum NOT IN (
				SELECT DISTINCT Chart+Account 
				FROM AD419.dbo.ArcCodeAccountExclusions
				WHERE Year = @FiscalYear
			) 
		group by 
			ARCCode, e.Chart, e.AccountNum, e.ConsolidationCode
		having sum(Expend) <> 0
	END

	-- Update the indirect expenses column on any account with direct expenses
	-- based on the indirect expenses we just pulled: 
	UPDATE @DirectAndIndirectExpenses
	SET IndirectTotal = t2.IndirectTotal
	FROM @DirectAndIndirectExpenses t1
	INNER JOIN @IndirectExpenses t2 ON t1.AnnualReportCode = t2.AnnualReportCode AND
	t1.Chart = t2.Chart AND t1.Account = t2.Account  AND t1.ConsolidationCode = t2.ConsolidationCode

	-- Insert any new accounts and expenses that have no direct expenses, but
	-- have indirect expenses only:
	INSERT INTO @DirectAndIndirectExpenses
	SELECT 
		t2.AnnualReportCode,
		t2.Chart,
		t2.Account, 
		t2.ConsolidationCode,
		0 AS DirectTotal,
		t2.IndirectTotal,
		0 AS Total 
	FROM @IndirectExpenses t2
	INNER JOIN (
	SELECT 
		AnnualReportCode, 
		Chart,
		Account,
		ConsolidationCode
	FROM @IndirectExpenses 
	EXCEPT
	SELECT 
		AnnualReportCode, 
		Chart,
		Account,
		ConsolidationCode
	FROM @DirectAndIndirectExpenses 
	) t3 ON t2.AnnualReportCode = t3.AnnualReportCode AND t2.Chart = t3.Chart AND t2.Account = t3.Account AND t2.ConsolidationCode = t3.ConsolidationCode

	-- Add the direct and indirect expenses together and update the total column
	-- for each ARC, chart and account record:
	UPDATE @DirectAndIndirectExpenses 
	SET Total = DirectTotal + IndirectTotal

	RETURN 
END