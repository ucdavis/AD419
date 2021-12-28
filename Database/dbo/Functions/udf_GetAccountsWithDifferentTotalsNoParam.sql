
-- =============================================
-- Author:		Ken Taylor
-- Create date: November 1st, 2017
-- Description:	Find and return any acconts where the 
-- totals are different between the Expenses and 
-- FFY_ExpensesByARC tables.
-- Usage:
/*
	SELECT * FROM udf_GetAccountsWithDifferentTotals()
*/
-- Testing for 2017:
/*
-- Change an expense so we can test it showing up on the list:
update allExpenses 
set 
expenses = 2520.09 *2 -- 2520.09
WHERE ExpenseID = 13020

-- delete the account we're using for testing:
DELETE FROM ArcCodeAccountExclusions
WHERE YEAR = 2017 and Account = 'REG6DDM'


-- restore the accounts we're using for testing:
INSERT INTO ArcCodeAccountExclusions
SELECT * FROM REG6DDM

update allExpenses 
set 
expenses = 2520.09
WHERE ExpenseID = 13020
*/
-- Modifications:
--	20191112 by kjt: Removed FiscalYear parameter, and now get FiscalYear from udf_GetFiscalYear.
--		Renamed udf_GetAccountsWithDifferentTotals to udf_GetAccountsWithDifferentTotalsForFiscalYearProvided
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetAccountsWithDifferentTotalsNoParam] 
(
	-- Add the parameters for the function here
	--@FiscalYear int = 2017 
)
RETURNS 
@AccountsWithDifferingTotals TABLE 
(
	-- Add the column definitions for the TABLE variable here
	Chart varchar(2), 
	Account varchar(7),
	FFY_ExpensesByARC_Total decimal(12,2),
	ExpensesTotal decimal(12,2)
)
AS
BEGIN
	DECLARE @FiscalYear int = (SELECT [dbo].[udf_GetFiscalYear]())
	-------------------
	-- This will give us back the accounts that are either missing or have different totals:
	-- NULL in the ExpensesTotal means the account is not present in expenses.  Different
	-- non-null totals means the expenses were either not entered fully or entered multiple times.
	-- Accounts not present in expenses probably means that no automatic match could be made and
	-- that the expenses belong to an account that is a sub-award on a project that is reported on
	-- by another entity, i.e. UC Santa Cruz, etc. An exclusion should be added for types of accounts. 

	INSERT INTO @AccountsWithDifferingTotals
	-- This gives us all accounts where either the accounts are not
	-- present in expenses or the totals differ for the same account:
	SELECT t1.Chart, t1.Account, t1.Expenses FFY_ExpensesByARC_Total, 
	SUM(t2.Expenses) ExpensesTotal 
	FROM (
		-- This gives us a list of accounts and ARC totals less 
		-- expenses for excluded accounts:
		SELECT Chart, Account, SUM(Total) Expenses
		FROM FFY_ExpensesByARC
		WHERE NOT EXISTS (
			-- This gives us a list of accounts present in FFY_ExpensesByARC 
			-- that we already know will be excluded from the expenses table: 
			SELECT DISTINCT Chart, Account FROM (

				-- These are the accounts pertaining to expenses for 
				-- 204 projects that are
				-- not expired, but have a project total across all
				-- it''s accounts that are less than $100 and have
				-- been excluded: 
				SELECT Chart, Account
				FROM AllAccountsFor204Projects 
				WHERE AccessionNumber IN (
					SELECT AccessionNumber 
					FROM allProjectsNew
					WHERE  Is204 = 1 AND IsExpired = 0 AND IsIgnored = 1
				)
				GROUP BY Chart, Account HAVING SUM(Expenses) <> 0

				UNION

				-- These are the accounts pertaining to expenses for 
				-- 204 projects that are outside of our ARCs or
				-- that have expired.  We exclude these expenses in
				-- both cases.
				SELECT Chart, Account
				FROM AllAccountsFor204Projects
				WHERE ExcludedByARC = 1 OR isExpired = 1

				UNION

				-- These are accounts we have already excluded for
				-- any reason, typically because they belong to projects
				-- that we are not responsible for reporting on.
				SELECT chart, account 
				FROM udf_ArcCodeAccountExclusionsForFiscalYear(@FiscalYear)
			) t1
			WHERE t1.Chart = FFY_ExpensesByARC.Chart AND t1.Account = FFY_ExpensesByARC.Account
		)
		GROUP BY chart, account HAVING SUM(TOTAL) <> 0

		EXCEPT

		-- This gives us the list of accounts and expense totals
		-- present in expenses
		SELECT DISTINCT Chart, Account, SUM(Expenses) Expenses
		FROM Expenses
		WHERE DataSource NOT IN ('CE', '22f') -- Exclude expenses entered manually.
		GROUP BY chart, account HAVING SUM(Expenses) <> 0

	) t1
	LEFT OUTER JOIN Expenses t2 ON t1.Chart = t2.Chart and t1.Account = t2.Account
	GROUP BY t1.Chart, t1.Account, t1.Expenses 
	ORDER BY t1.Chart, t1.Account, t1.Expenses
	
	RETURN 
END