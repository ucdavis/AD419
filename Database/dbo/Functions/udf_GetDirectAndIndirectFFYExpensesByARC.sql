-- =============================================
-- Author:		Name
-- Create date: Ken Taylor
-- Description:	Return a list of Direct and Indirect FFY expenses via ARC code.
--
-- Usage: 
/*
	SELECT * FROM udf_GetDirectAndIndirectFFYExpensesByARC(2015)
*/
--
-- Modifications:
--	20160818 by kjt: Fixed issue using Account, i.e., 
--		Chart+'-'+Account, Vs. AccountNum, i.e. 7-character account number only.
-- =============================================
CREATE FUNCTION [dbo].[udf_GetDirectAndIndirectFFYExpensesByARC] 
(
	@FiscalYear int
)
RETURNS 
@DirectAndIndirectFFYExpenses TABLE 
(
	AnnualReportCode varchar(20), 
	Chart varchar(2),
	Account varchar(7),
	DirectTotal money,
	IndirectTotal money,
	Total money
)
AS
BEGIN
	INSERT INTO @DirectAndIndirectFFYExpenses
	select 
	AnnualReportCode,
	Chart,
	AccountNum Account,
	sum(Expend) DirectTotal,
	0 AS IndirectTotal,
	0 AS Total
from 
	FISDatamart.dbo.BalanceSummaryV e inner join 
	FISDatamart.dbo.ARCCodes a on e.AnnualReportCode = a.ARCCode
where 
	((e.FiscalYear = @FiscalYear AND e.FiscalPeriod BETWEEN '04' AND '13') OR 
	 (e.FiscalYear = @FiscalYear + 1 AND e.FiscalPeriod BETWEEN '01' AND '03'))
	AND TransBalanceType IN ('AC')
	AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') AND ConsolidationCode NOT LIKE 'INDR' AND  TransBalanceType = 'AC' 
	and Account NOT IN (
		SELECT DISTINCT Chart+'-'+Account 
		FROM AD419.dbo.ArcCodeAccountExclusions
		WHERE Year = @FiscalYear
	) 
group by 
	e.AnnualReportCode , e.Chart, e.AccountNum
order by 
	e.AnnualReportCode , e.Chart, e.AccountNum

UPDATE @DirectAndIndirectFFYExpenses
SET IndirectTotal = t2.Total
FROM @DirectAndIndirectFFYExpenses t1
INNER JOIN (
select 
	AnnualReportCode,
	Chart,
	AccountNum Account, 
	sum(Expend) Total 
from 
	FISDatamart.dbo.BalanceSummaryV e inner join 
	FISDatamart.dbo.ARCCodes a on e.AnnualReportCode = a.ARCCode
where 
	((e.FiscalYear = @FiscalYear AND e.FiscalPeriod BETWEEN '04' AND '13') OR 
	 (e.FiscalYear = @FiscalYear + 1 AND e.FiscalPeriod BETWEEN '01' AND '03'))
	AND TransBalanceType IN ('AC')
	AND ConsolidationCode  LIKE 'INDR' AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74') 
	and Account NOT IN (
		SELECT DISTINCT Chart+'-'+Account 
		FROM AD419.dbo.ArcCodeAccountExclusions
		WHERE Year = @FiscalYear
	) 
group by 
	e.AnnualReportCode , e.Chart, e.AccountNum
) t2 ON t1.AnnualReportCode = t2.AnnualReportCode AND t1.Chart = t2.Chart AND t1.Account = t2.Account

UPDATE @DirectAndIndirectFFYExpenses
SET Total =  DirectTotal + IndirectTotal
	
	RETURN 
END