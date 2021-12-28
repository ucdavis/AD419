/****** Script for SelectTopNRows command from SSMS  ******/
-- Author: Ken Taylor
-- Created: December 11, 2018
--
-- Background:
-- The 2017-2018 reporting year had five (5) projects that had no expense
--	accounts, and therefore, no expenses whatsoever; therefore, these 
--	projects had no account expenses present in the FFY_SFN_Entries table.
--	This resulted in the "IsIgnored flag not being set for these 5 projects, and the 
--	departments were able to prorate expenses against them, which is not what
--	we wanted.  This also resulted in admin expenses being prorated against 
--	them as well, which we also did not want.  In order to correct this for the
--	2017-18 reporting year in I had to
--	delete all of the corresponding associations for these 5, and then reset the
--	"IsAssociated" flag back to false so that Shannon could prorate the
--	remaining expenses against the intended projects list, meaning less these 5,
--	with no expense accounts, plus the other 8 for which their account's expenses
--  were < $100.  There were thirteen (13) total 204 projects meeting this criteria. 
--
-- Description: Return a list of any 204 projects which do not have expenses >= $100.  
--	 This allows us to also include those which have no expense accounts, and therefore, 
--	 no expenses whatsoever.
--
-- Usage:
/*
	USE [AD419]
	GO

	SELECT AccessionNumber
	FROM [dbo].[204ProjectsWithMinimalExpensesV]

*/
-- Modifications:
--
CREATE VIEW [dbo].[204ProjectsWithMinimalExpensesV]
AS
	SELECT 
		  [AccessionNumber]
	  FROM [AD419].[dbo].[AD419CurrentProjectListV] t1
	  WHERE Is204 = 1 AND  
		  NOT EXISTS (
		  -- Return a list of all current projects with expenses >= $100
		  --   as these will be the ones we want to exclude from our
		  --   "204 projects with no expense accounts or expenses < $100" list.
			SELECT 1
			FROM FFY_SFN_Entries t2
			WHERE t1.AccessionNumber = t2.AccessionNumber
			GROUP BY t2.AccessionNumber
			HAVING SUM(Expenses) >= 100
		  )