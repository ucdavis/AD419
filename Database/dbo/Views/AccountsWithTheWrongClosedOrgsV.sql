



/*
-- Author: Ken Taylor
-- Created: 2019-09-03
-- Description: This should give us enough info to be able to make an informed decision about which Org/OrgR to use.
-- Usage:

	USE [AD419]
	GO

	SELECT * FROM [dbo].[AccountsWithTheWrongClosedOrgsInfoV]
	ORDER BY Chart, Account

-- Modifications:
--	2019-09-09 by kjt: Added filter for AD-419 accounts whith have already been updated or confirmed.
*/
CREATE VIEW [dbo].[AccountsWithTheWrongClosedOrgsV]
AS
SELECT DISTINCT TOP 100 PERCENT  
                         t1.Chart, t1.Account, t2.Expenses, CurrentOrg, LatestNonClosedOrg, CurrentOrgR, LatestNonClosedOrgR, CONVERT(varchar(4), LatestNonClosedYear) + '-' + CONVERT(varchar(2),LatestNonClosedPeriod) AS LatestNonClosedYearPeriod, 
                         t3.Purpose AS AccountPurpose, t3.AccountName, t4.Name AS CurrentOrgName, t5.Name AS LatestNonClosedOrgName, 
                         t5.HomeDeptName AS LatestNonClosedHomeDepartment
FROM            FISDataMart.dbo.AccountsWithTheWrongClosedOrgsV t1 INNER JOIN
                         AD419Accounts t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account LEFT OUTER JOIN
                         FISDataMart.dbo.Accounts t3 ON t1.Chart = t3.Chart AND t1.Account = t3.Account AND Year = 9999 AND Period = '--' LEFT OUTER JOIN
                         FISDATAMART.dbo.Organizations_UFY t4 ON t1.Chart = t4.Chart AND t1.CurrentOrg = t4.Org LEFT OUTER JOIN
                         FISDATAMART.dbo.Organizations_UFY t5 ON t1.Chart = t5.Chart AND t1.LatestNonClosedOrg = t5.Org
WHERE NOT EXISTS (
	SELECT 1
	FROM dbo.[AD419Accounts] t2
	WHERE t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.HaveOrgsBeenAdjusted IS NOT NULL
)
ORDER BY t1.Chart, T1.Account