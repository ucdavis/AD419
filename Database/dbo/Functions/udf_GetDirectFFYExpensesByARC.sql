-- =============================================
-- Author:		Name
-- Create date: Ken Taylor
-- Description:	Return a list of Direct FFY expenses via ARC code.
--
-- Usage: 
/*

SELECT * FROM udf_GetDirectFFYExpensesByARC(2016)

*/
-- Modifications: 
--	20171003 by kjt: Added "SUB9" to the object exclusion list as per discussion with Shannon Tanguay 2017-10-02.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetDirectFFYExpensesByARC] 
(
	@FiscalYear int = 2016
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
	AND ConsolidationCode NOT LIKE 'INDR'
	AND ConsolidationCode NOT IN ('INC0', 'BLSH', 'SB74', 'SUB9') 
	and Account NOT IN (
		SELECT DISTINCT Chart+'-'+Account 
		FROM AD419.dbo.ArcCodeAccountExclusions
		WHERE Year = @FiscalYear
	) 
group by 
	e.AnnualReportCode --, e.Chart--, e.Account
order by 
	e.AnnualReportCode --, e.Chart--, e.Account
	
	RETURN 
END