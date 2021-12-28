
-- Author: Ken Taylor
-- Created: 2019-01-16
--
-- Description: Return a list of chart, account and their most recent Org that is not in the following expired Orgs list:
--	'DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED'.
-- This is accomplished by drilling down to find the most recent Org for any account in our accounts table, which has an Org that is not one in the above list. 
--
-- Purpose: This is because someone assigns an expired account to closed org belonging to the wrong department
-- withing a cluster and the expenses would otherwise be associated by the incorrect department.
--
-- Usage:
/*
	SELECT * FROM [dbo].[NonExpiredOrgDrillDownV]

	-- OR --

  UPDATE NewAccountSFN
  SET Org = t2.Org
  FROM NewAccountSFN t1
  INNER JOIN [AD419].[dbo].[NonExpiredOrgDrillDownV] t2 On t1.Chart = t2.Chart and t1.Account = t2.Account

*/
--
-- Modifications:
--
CREATE VIEW [dbo].[NonExpiredOrgDrillDownV]
AS
SELECT DISTINCT 
                         TOP (100) PERCENT 
						 tUniversalFiscalYear.Chart, tUniversalFiscalYear.Account, 
						 CASE 
							WHEN tUniversalFiscalYear.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tUniversalFiscalYear.Org 
							WHEN tFiscalYear07.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear07.Org 
							WHEN tFiscalYear04.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear04.Org 
							WHEN tFiscalYear.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear.Org 
							WHEN tFiscalYearMinus1.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus1.Org 
							WHEN tFiscalYearMinus2.Org NOT IN ('DUMP', 'EXPR',  'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus2.Org 
							WHEN tFiscalYearMinus3.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus3.Org 
							WHEN tFiscalYearMinus4.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus4.Org 
							WHEN tFiscalYearMinus5.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus5.Org 
							WHEN tFiscalYearMinus6.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus6.Org 
							WHEN tFiscalYearMinus7.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus7.Org 
						END AS Org, 
						COALESCE (t2.OrgR, t7.OrgR) AS OrgR
FROM            FISDataMart.dbo.Accounts AS tUniversalFiscalYear 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYearMinus1 ON tUniversalFiscalYear.Chart = tFiscalYearMinus1.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus1.Account AND 
					tFiscalYearMinus1.Year = (SELECT        dbo.udf_GetFiscalYear() - 1 AS Expr1) AND tFiscalYearMinus1.Period = '--' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYear04 ON tUniversalFiscalYear.Chart = tFiscalYear04.Chart AND tUniversalFiscalYear.Account = tFiscalYear04.Account AND 
					tFiscalYear04.Year =  (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND tFiscalYear04.Period = '04' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYearMinus7 ON tUniversalFiscalYear.Chart = tFiscalYearMinus7.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus7.Account AND 
					tFiscalYearMinus7.Year = (SELECT        dbo.udf_GetFiscalYear() - 7 AS Expr1) AND tFiscalYearMinus7.Period = '--' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYearMinus6 ON tUniversalFiscalYear.Chart = tFiscalYearMinus6.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus6.Account AND 
					tFiscalYearMinus6.Year = (SELECT        dbo.udf_GetFiscalYear() - 6 AS Expr1) AND tFiscalYearMinus6.Period = '--' 
				LEFT OUTER JOIN  FISDataMart.dbo.Accounts AS tFiscalYearMinus5 ON tUniversalFiscalYear.Chart = tFiscalYearMinus5.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus5.Account AND 
					tFiscalYearMinus5.Year =  (SELECT        dbo.udf_GetFiscalYear() - 5 AS Expr1) AND tFiscalYearMinus5.Period = '--' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYearMinus4 ON tUniversalFiscalYear.Chart = tFiscalYearMinus4.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus4.Account AND 
					tFiscalYearMinus4.Year =  (SELECT        dbo.udf_GetFiscalYear() - 4 AS Expr1) AND tFiscalYearMinus4.Period = '--' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYearMinus3 ON tUniversalFiscalYear.Chart = tFiscalYearMinus3.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus3.Account AND 
					tFiscalYearMinus3.Year = (SELECT        dbo.udf_GetFiscalYear() - 3 AS Expr1) AND tFiscalYearMinus3.Period = '--' 
				LEFT OUTER JOIN  FISDataMart.dbo.Accounts AS tFiscalYearMinus2 ON tUniversalFiscalYear.Chart = tFiscalYearMinus2.Chart AND tUniversalFiscalYear.Account = tFiscalYearMinus2.Account AND 
					tFiscalYearMinus2.Year = (SELECT        dbo.udf_GetFiscalYear() - 2 AS Expr1) AND tFiscalYearMinus2.Period = '--' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYear07 ON tUniversalFiscalYear.Chart = tFiscalYear07.Chart AND tUniversalFiscalYear.Account = tFiscalYear07.Account AND 
					tFiscalYear07.Year = (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND tFiscalYear07.Period = '07' 
				LEFT OUTER JOIN FISDataMart.dbo.Accounts AS tFiscalYear ON tUniversalFiscalYear.Chart = tFiscalYear.Chart AND tUniversalFiscalYear.Account = tFiscalYear.Account AND 
						 tFiscalYear.Year = (SELECT        dbo.udf_GetFiscalYear() AS Expr1) AND tFiscalYear.Period = '--' 
				LEFT OUTER JOIN dbo.ReportingOrg AS t7 ON tUniversalFiscalYear.Org = t7.OrgR AND t7.IsActive = 1 
				LEFT OUTER JOIN  dbo.UFYOrganizationsOrgR_v AS t2 ON tUniversalFiscalYear.Chart = t2.Chart AND 
					t2.Org = 
					CASE 
						WHEN tUniversalFiscalYear.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tUniversalFiscalYear.Org 
						WHEN tFiscalYear07.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear07.Org 
						WHEN tFiscalYear04.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear04.Org 
						WHEN tFiscalYear.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYear.Org 
						WHEN tFiscalYearMinus1.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus1.Org 
						WHEN tFiscalYearMinus2.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus2.Org 
						WHEN tFiscalYearMinus3.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus3.Org 
						WHEN tFiscalYearMinus4.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus4.Org 
						WHEN tFiscalYearMinus5.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus5.Org 
						WHEN tFiscalYearMinus6.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus6.Org 
						WHEN tFiscalYearMinus7.Org NOT IN ('DUMP', 'EXPR', 'GONE', 'CLOS', 'ZERO', 'AAES', 'PDED') THEN tFiscalYearMinus7.Org 
					END
WHERE        (tUniversalFiscalYear.Year = 9999) AND (tUniversalFiscalYear.Period = '--')
ORDER BY	tUniversalFiscalYear.Chart, tUniversalFiscalYear.Account