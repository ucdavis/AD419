-- =============================================
-- Author:		Name
-- Create date: Ken Taylor
-- Description:	Return a list of Indirect FFY expenses via ARC code.
-- Usage: SELECT * FROM udf_GetIndirectFFYExpensesByARC(2015)
-- =============================================
CREATE FUNCTION udf_GetIndirectFFYExpensesByARC 
(
	@FiscalYear int
)
RETURNS 
@DirectFFYExpenses TABLE 
(
	AnnualReportCode varchar(20), 
	--Chart,
	--Account,
	Total money
)
AS
BEGIN
	INSERT INTO @DirectFFYExpenses
	select 
	AnnualReportCode,
	--Chart,
	--Account, 
	sum(Expend) Total 
from 
	FISDatamart.dbo.BalanceSummaryV e inner join 
	FISDatamart.dbo.ARCCodes a on e.AnnualReportCode = a.ARCCode
where 
	((e.FiscalYear = @FiscalYear AND e.FiscalPeriod BETWEEN '04' AND '13') OR 
	 (e.FiscalYear = @FiscalYear + 1 AND e.FiscalPeriod BETWEEN '01' AND '03'))
	AND TransBalanceType IN ('AC')
	AND ConsolidationCode  LIKE 'INDR'
	and Account NOT IN (
		SELECT DISTINCT Chart+'-'+Account 
		FROM AD419.dbo.ArcCodeAccountExclusions
		WHERE Year = @FiscalYear
	) 
group by 
	e.AnnualReportCode --, e.Chart--, e.Account
order by 
	e.AnnualReportCode -- , e.Chart--, e.Account
	
	RETURN 
END