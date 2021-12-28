/*
Author: Ken Taylor
Created: January 25,2019
Description: Find a list of all AAES accounts that have moved to another orgR.
Usage:

USE [FISDataMart]
GO

SELECT * FROM [dbo].[AccountsThatHaveMovedOrgRsV]
GO

Modifications:
	20190131 by kjt: Totally revised to handle accounts that have had moved both orgs and orgRs that have
	moved OrgRs, and are not the result of  of a departmental merge or reorganization.

*/

CREATE VIEW [dbo].[AccountsThatHaveMovedOrgRsV]
AS
SELECT TOP 100 PERCENT
	t1.Year FormerYear, /*OrgR Year*/
	t1.Chart, 
	t1.Account, 
	t1.Org FormerOrg, 
	t2.Org CurrentOrg, 
	t1.OrgR FormerOrgR, 
	t3.OrgR AS CurrentOrgR 
	/*,t1.Period FormerOrgRPeriod*/  
FROM (
	SELECT t1.Chart, t1.Account, t1.Org, t2.OrgR, t2.Year, t2.Period 
	FROM (
		SELECT 
			row_number() OVER (PARTITION BY t1.Chart, t1.Account, t1.Org ORDER BY Year DESC, Period DESC) as RowNum, 
			t1.Chart, t1.Account, t1.Org, t1.Year, t1.Period
		FROM Accounts t1 
		WHERE 
		  NOT EXISTS  (
			SELECT 1
			FROM  Accounts t2 
		WHERE t1.Chart = t2.Chart and  t1.Account = t2.Account AND t1.Org = t2.Org AND t2.Year = 9999 AND t2.Period = '--'  
		)
	) t1 
	INNER JOIN 
	(
		SELECT t2.Chart, t2.Org, t2.OrgR, t2.Year, t2.Period
		FROM ( 
			SELECT Row_Number () OVER (PARTITION BY t2.Chart, t2.Org ORDER BY t2.Year DESC, t2.Period DESC) AS RowNum, 
				t2.Chart, t2.Org, 
				CASE t2.OrgR 
					WHEN 'ANEM' THEN 'AENM' WHEN 'AENT' THEN 'AENM'
					WHEN 'AHCD' THEN 'AHCE' WHEN 'AHCH' THEN 'AHCE 'WHEN 'ALAR' THEN 'AHCE'  
					WHEN 'ACTR' THEN 'ADNO' WHEN 'AGAD' THEN 'ADNO' WHEN 'AWRD' THEN 'ADNO' WHEN 'ALAB' THEN 'ADNO'
					WHEN 'USDA' THEN 'ANUT'
					WHEN 'ACEP' THEN 'APPA'
					ELSE t2.OrgR 
				END OrgR, 
				Year, Period 
			FROM OrganizationsV t2
			WHERE 
			 NOT EXISTS (
				SELECT 1
				FROM OrganizationsV t3
				WHERE t3.Year = 9999 AND t3.Period = '--'
				AND t2.Chart = t3.Chart AND t2.Org = t3.Org AND t2.OrgR = t3.OrgR
			)
		) t2
		WHERE RowNum = 1
	) t2 ON t1.Chart = t2.Chart AND t1.Org = t2.Org
	WHERE RowNum = 1
) t1
INNER JOIN Accounts t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.Year = 9999 AND t2.Period = '--'
INNER JOIN OrganizationsV t3 ON t2.Chart = t3.Chart AND t2.Org = t3.Org AND t3.Year = 9999 AND t3.Period = '--'
WHERE t3.OrgR NOT LIKE 'B%' AND t1.OrgR NOT LIKE 'B%' 
GROUP BY t1.Chart, t1.Account, t1.Org, t2.Org, t1.OrgR, t3.OrgR , t1.Year, t1.Period
HAVING t1.OrgR != t3.OrgR  
ORDER BY t1.Chart, t1.Account