------------------------------------------------------------------------
/*
UDF Name: udf_Adjusted_FIS_Expenses
BY:	Mike Ransom

DESCRIPTION: 
	Produces a merged dataset of unadjusted + adjusted FIS expenses  (FIS + PPS-sourced reversals).  Done with a UNION of data from Expenses_CAES  (a table) and Expenses_Salary_Reversals (a view (which itself is dependent on another view)).  The "reversal" amounts are *subtracted*, so the value summed is (- Expenses_Salary_Reversals.ReversalAmt).
	 
	 The result can be queried or INSERTed into the AD419_Expenses_Dataset table as an abstracted "Adjusted FIS Expenses" dataset.


CURRENT STATUS:
[11/3/06] Fri
	Working. 20955 rows, 1 second


USAGE:
	SELECT * FROM udf_Adjusted_FIS_Expenses()

*/
-------------------------------------------------------------------------
CREATE FUNCTION [dbo].[udf_Adjusted_FIS_Expenses]()
RETURNS @FIS_Expenses TABLE
	(
	Chart char(1),
	Org_R char(4),
	Account varchar(7),
	SubAccount varchar(5),
	Expend float
	)	
AS
-------------------------------------------------------------------------
BEGIN


INSERT INTO @FIS_Expenses
	(
	Chart,
	Org_R,
	Account,
	SubAccount,
	Expend
	)
	SELECT
		Expenses_CAES.Chart, 
		OrgR.OrgR AS Org_R, 
		Expenses_CAES.Account, 
		Expenses_CAES.SubAccount, 
		Expenses_CAES.ExpenseSum AS Expend
	FROM         
		Expenses_CAES 
		INNER JOIN OrgXOrgR AS OrgR ON 
			Expenses_CAES.Chart = OrgR.Chart
			AND Expenses_CAES.Org = OrgR.Org
	UNION
	SELECT
		'3' AS Chart,
		Org_R,
		Account,
		SubAccount,
		(- ReversalAmt) AS Expend
	FROM
		Expenses_Salary_Reversals
RETURN
END
-------------------------------------------------------------------------
/*
CALLED BY:
	sp_Repopulate_AD419_FIS_Expenses

DEPENDENCIES: 
	Expenses_CAES (table)
	Expenses_Salary_Reversals (view)

MODIFICATIONS:
[11/15/05] Tue
	Created.
[11/22/05] Tue
	Remove column DataSource (which was being set to 'FIS'). This better done outside of this UDF.
	23,098 rows in 4 seconds

*/
