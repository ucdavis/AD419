------------------------------------------------------------------------
/*
PROGRAM: usp_denormalization_updates_of_AD419
BY:	Mike Ransom
USAGE:	EXEC usp_denormalization_updates_of_AD419

DESCRIPTION: 

CURRENT STATUS:


NOTES:

DEPENDENCIES, CALLED BY, and MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_denormalization_updates_of_AD419]
AS
-----------------------------------------------------------------------------
BEGIN

--Account Name
UPDATE AD419 
SET 
	AD419.acct_name = Account.AccountName, 
	AD419.PI = Account.PrincipalInvestigatorName
FROM 
	AD419_Expenses_Dataset as AD419, FISDataMart.dbo.Accounts as Account
	WHERE
		AD419.chart = Account.Chart
		AND AD419.acct_id = Account.Account
		AND Year = 9999 and Period = '--'


/*
*/
END
-------------------------------------------------------------------------
/*
CALLED BY:

DEPENDENCIES:

MODIFICATIONS:

*/
