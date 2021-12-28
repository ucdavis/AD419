﻿-- =============================================
-- Author:		Ken Taylor
-- Create date: July 11, 2016
-- Description:	Load the AD419Accounts table.
-- Get a list of all unique accounts that are in the FFY ARC accounts table,
-- plus any missing 204 accounts that were excluded by ARC, etc,
-- and load them into the AD419Accounts table.
-- This table contains a list of all CA&ES accounts, their SFN, and expenses that
-- were pulled from FIS by ARC, plus whatever additional 204 expense accounts that were 
-- outside our ARCs and pulled by OpFundNum 
--
-- Prerequisites:
-- 1. The FFY_ExpensesByARC table must have already been loaded
-- 2. The NewAccountSFN table must have already been loaded
-- 3. The AllAccountsFor204Projects table must have already been loaded
--
-- Usage:
/*
	USE AD419 
	GO

	EXEC usp_LoadAD419Accounts
*/
-- Modifications:
--	2016-08-19 by kjt: Revised to use UFYOrganizationsOrgR_v
--	2017-09-26 by kjt: Removed having clause for adding any missing 204 accounts so that
--		204 accounts with no expenses would also be included; otherwise, we are not ablew to exclude 
--		and re-include them properly.
--	2017-10-12 by kjt: Revised the joins because we already have the Org present in NewAccountSFN,
--		so it is not necessary to do another join on Accounts.
--	2017-10-13 by kjt: Changed FFY_ExpensesByARC join with NewAccountSFN to use OrgXOrgR instead of 
--		UFYOrganizationsOrgR_v since this can change over the year if run retroactively.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadAD419Accounts] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	TRUNCATE TABLE dbo.AD419Accounts
	-- Get all the unique chart/account combinations from the FFY_ExpensesByARC table with
	-- expenses not equal to zero:

	INSERT INTO dbo.AD419Accounts(
	   [Chart]
      ,[Account]
      ,[Org]
      ,[OrgR]
      ,[Expenses]
      ,t4.[SFN]
      ,[IsExpired])

    SELECT DISTINCT
       t1.[Chart]
      ,t1.[Account]
	  ,t4.Org
	  ,t3.OrgR
      ,SUM([Total]) Expenses
	  ,CONVERT(varchar(5),t4.SFN) SFN
	  ,CONVERT(bit,NULL) AS IsExpired
	--INTO AD419Accounts
	FROM [AD419].[dbo].[FFY_ExpensesByARC]  t1
	INNER JOIN  [dbo].[NewAccountSFN] t4 ON t1.chart = t4.Chart and t1.Account = t4.Account -- This gets us the Org we need for the OrgR join.
	LEFT OUTER JOIN [dbo].[OrgXOrgR] t3 ON t4.Chart = t3.Chart AND t4.Org = t3.Org
	group by t1.Chart, t1.Account, t4.SFN, t3.OrgR, 
	t4.Org  having SUM(Total) <> 0
	order by t1.Chart, t1.Account , t3.OrgR, 
	t4.Org 

	-- Add records for any 204 accounts that were excluded by ARC, etc:
	-- 2017-09-26 by kjt: Removed having clause to include accounts with no expenses. 
	INSERT INTO AD419Accounts (
		Chart, Account, Org, OrgR, Expenses, SFN
	)
	SELECT DISTINCT
		   t1.[Chart]
		  ,t1.[Account]
		  ,t2.Org
		  ,t2.OrgR
		  ,SUM(t1.Expenses) Expenses,
		  '204' AS SFN
	  
	FROM (
		SELECT Chart, Account, SUM(Expenses) Expenses
		FROM [dbo].[AllAccountsFor204Projects]
		GROUP BY Chart, Account, IsExpired --having sum(Expenses) <> 0

		EXCEPT

		SELECT [Chart]
			  ,[Account]
			  ,SUM(Expenses) Expenses
		  FROM [dbo].[AD419Accounts]
		  GROUP BY CHART, Account --having sum(Expenses) <> 0
	) t1
	 -- LEFT OUTER JOIN FisDataMart.dbo.Accounts t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account AND t2.Year = 9999 AND t2.Period = '--'
	  LEFT OUTER JOIN [dbo].[AllAccountsFor204Projects] t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	  --LEFT OUTER JOIN dbo.UFYOrganizationsOrgR_v t3 ON t1.Chart = t3.Chart AND t2.Org = t3.Org -- AND t2.Year = t3.Year and t2.Period = t3.Period
	  group by t1.Chart, t1.Account, t2.OrgR, t2.Org 
	  order by t1.Chart, t1.Account, t2.OrgR, t2.Org

	-- Update several fields pertaining to 204 specific accounts:
	update AD419Accounts
	Set SFN = '204'
	FROM AD419Accounts t1
	INNER JOIN  [AD419].[dbo].[AllAccountsFor204Projects] t2 ON t1.Chart = t2.Chart and T1.Account = t2.Account

	update AD419Accounts
	Set IsExpired = t2.IsExpired 
	FROM AD419Accounts t1
	INNER JOIN  [AD419].[dbo].[AllAccountsFor204Projects] t2 ON t1.Chart = t2.Chart and T1.Account = t2.Account
	WHERE t1.SFN = '204'
	------------------------------------------------------------

	-- Update the SFN for non-204 project accounts:
	update [AD419].[dbo].[AD419Accounts]
	set SFN = t2.SFN
	FROM [AD419].[dbo].[AD419Accounts] t1
	INNER JOIN NewAccountSFN t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	WHERE t1.SFN IS NULL OR t1.SFN <> '204'
END