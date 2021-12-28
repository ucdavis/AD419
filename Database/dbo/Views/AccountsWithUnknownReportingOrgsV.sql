

------------------------------------------------------------------------------------
-- CREATED BY: Ken Taylor
-- CREATED ON:???
-- DESCRIPTION: Return a list of closed accounts whose OrgRs have changed to a 
--	different OrgR from what it was when the account was last opened.
-- USAGE:
/*


*/
-- Modifications:
-- 20201124 by kjt: COALESCE(t1.[Expenses],0) to the Expenses as some expenses totals
--		were being returned as NULL, probably because the account data was not present,
--		and this was causing issues with the DataHelper application.
-- 20201124 by kjt: Added logic to exclude accounts present in ARC/Account exclusions table.
--
------------------------------------------------------------------------------------
CREATE VIEW [dbo].[AccountsWithUnknownReportingOrgsV]
AS
SELECT DISTINCT t1.[Chart]
      ,t1.[Account]
	  ,COALESCE(t1.[Expenses],0) Expenses
      ,t1.[Org] CurrentOrg
	  ,t5.Org LatestNonClosedOrg
      ,t1.[OrgR] CurrentOrgR
	  ,COALESCE(t7.AD419OrgR, t6.OrgR)  LatestNonClosedOrgR
	  ,CONVERT(varchar(4), t5.year) + '-' + t5.Period AS LatestNonClosedYearPeriod
	  ,Purpose AS AccountPurpose
	  ,AccountName
	  ,t8.Name AS CurrentOrgName
	  ,COALESCE(t9.Name, t8.Name) AS LatestNonClosedOrgName
	  ,COALESCE(t10.HomeDeptName, t8.HomeDeptName)  AS LatestNonClosedHomeDepartment
  FROM [AD419].[dbo].[AD419Accounts] t1
  INNER JOIN [FISDataMart].[dbo].[ClosedOrgsV] t2 ON t1.Chart = t2.Chart AND t1.Org = t2.Org
  INNER JOIN  [dbo].[udf_GetExpensesForNullOrUnknownDepartments] () t3 ON t1.Chart = t3.Chart AND t1.Org = t3.Org
  CROSS APPLY [dbo].[udf_GetAccountDataWithNonClosedOrg](t1.Chart, t1.Account) t5
  LEFT OUTER JOIN [FISDataMart].[dbo].[Organizations_UFY_OrgR_v] t6 ON t5.Chart = t6.Chart AND t5.Org = t6.Org
  LEFT OUTER JOIN [dbo].[ExpenseOrgR_X_AD419OrgR] t7 ON t6.OrgR = t7.ExpenseOrgR AND t6.Chart = t7.Chart AND t5.Org = t7.ExpenseOrg
  LEFT OUTER JOIN FISDATAMART.dbo.Organizations_UFY t8 ON t1.Chart = t8.Chart AND t1.Org = t8.Org 
  LEFT OUTER JOIN FISDATAMART.dbo.Organizations_UFY t9 ON t1.Chart = t9.Chart AND t6.Org = t9.Org 
  LEFT OUTER JOIN FISDATAMART.dbo.Organizations_UFY t10 ON t7.Chart = t10.Chart AND t7.AD419OrgR = t10.Org
  WHERE NOT EXISTS (
	SELECT 1
	FROM dbo.[AD419Accounts] t2
	WHERE t1.Chart = t2.Chart AND t1.Account = t2.Account AND t2.HaveOrgsBeenAdjusted IS NOT NULL
) AND NOT EXISTS (
	SELECT 1 FROM [dbo].[ARCCodeAccountExclusionsV] t3
	WHERE t1.Chart = t3.Chart AND t1.Account = t3.Account 
)