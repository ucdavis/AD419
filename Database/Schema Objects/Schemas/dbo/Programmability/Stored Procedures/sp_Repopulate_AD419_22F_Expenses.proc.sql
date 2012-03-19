------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_22F_Expenses
BY:	Mike Ransom
DESCRIPTION: 

USAGE:	
	EXECUTE sp_Repopulate_AD419_22F_Expenses

CURRENT STATUS:
[12/6/05] Tue	Started. Finished.

TODO:

NOTES:

DEPENDENCIES, CALLED BY, and MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_22F_Expenses]
AS
-------------------------------------------------------------------------
BEGIN

--Delete all 22F-sourced expense records:
DELETE FROM AD419_Expenses_Dataset 
	WHERE DataSource = '22F'

-------------------------------------------------------------------------
--Insert 
	--(48 row(s) affected)

	--Note: In order to generate the final Associations, there needs to be some way of identifying specific rows from the Expenses_CSREES table so that the Accession number can be associated with the expense.  Expenses_CSREES.PK, the PK, is the only unique identifying value.  I decided that the best thing to do would be to put this value in the AD419_Expenses_Dataset.Sub_Acct column, since it isn't used in the final dataset.

	--This insert *doesn't* aggregate any expenses, as these specific expenses are already specifically associated with projects.

	--None of the info for Account,subaccount, EID, Name,PI, etc. is needed, at that info is only used to aid the manual associations.  (Yipee!)
	
INSERT INTO AD419_Expenses_Dataset
	(DataSource, Chart, Org_3, exp_sfn, Expend, Associated, SubAcct_Nm)
	(
	SELECT 
		'22F' AS Datasource, 
		'3' AS Chart, 
		Org_R AS Org_3, 
		'22F' as exp_sfn,
		Expense, 
		1 AS Associated, 
		P.Accession AS SubAcct_Nm
	FROM 
		[Expenses_Field_Stations] AS E
			INNER JOIN Project P ON
				E.Accession = P.Accession
	WHERE
		Expense <> 0
		--AND Accession IS NOT NULL		--not needed now, with inner join to Project
	)

END
-------------------------------------------------------------------------
/*
CALLED BY:

DEPENDENCIES:
	

MODIFICATIONS:

*/
