------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_219_Expenses
BY:	Ken Taylor
DESCRIPTION: 

CURRENT STATUS:
	Working properly.

TODO:

NOTES:

--USAGE:	
	EXECUTE sp_Repopulate_AD419_219_Expenses

DEPENDENCIES:
	Table 204AcctXProj needs to be populated with the 204/219 expenses from the FIS/PPS extracts
	Then the "204" data entry performed to associate the expense's Accounts to projects (204AcctXProj.Accession entered in UI).

	Any data that is not associated in the 204AcctXProj table is deemed as a 219 expense and treated accordingly
	if @ConvertExpensesWithNullAccessionNumbers = 1.
MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_219_Expenses](
	@FiscalYear int = 2009,
	@ConvertExpensesWithNullAccessionNumbers bit = 0,
	@IsDebug bit = 0
)
AS
-------------------------------------------------------------------------
BEGIN
	DECLARE @TSQL varchar(MAX) = null
	
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
	--Delete all 219, 204AcctXProj sourced expense records:
	PRINT '-- DELETE FROM AllExpenses WHERE DataSource = ''219''...'
	Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''219''
	;'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END				

-------------------------------------------------------------------------
	
	-- Insert all the records that remain.  These either have is219 set to 1
	-- or isCurrentProject = 0 or no accession number.
	PRINT '--Inserting 219 expenses...'
	-- This will insert a single record each account/expense entry.
	Select @TSQL = 'INSERT INTO AllExpenses
		(DataSource, Chart, OrgR, Account, PI_Name, Expenses, isNonEmpExp, isAssociated, isAssociable, Org, Exp_SFN)
		(
		SELECT distinct ''219'' DataSource, E.Chart, O.OrgR, E.AccountID, 
		PrincipalInvestigatorName PI_Name,
		sum(E.DividedAmount) Expenses, 1, 0, 1, A.Org, ''219'' Exp_SFN
		FROM [204AcctXProj] E
			LEFT JOIN FISDataMart.dbo.Accounts A ON 
				E.AccountID = A.Account
				AND A.Year = ' + Convert(char(4), @FiscalYear) + '
				AND A.Period = ''--''
				AND E.Chart = A.Chart
			LEFT JOIN Acct_SFN as SFN ON
				A.Account = SFN.Acct_ID
				AND  A.Chart = SFN.Chart
				AND SFN.SFN = ''204''
				AND A.Year = ' + Convert(char(4), @FiscalYear) + '
				AND A.Period = ''--''
			LEFT JOIN OrgXOrgR O ON
				A.Org = O.Org
				AND A.Chart = O.Chart
				AND A.Year = ' + Convert(char(4), @FiscalYear) + '
				AND A.Period = ''--''
		WHERE E.Is219 = 1 OR E.IsCurrentProject = 0'
		
		if @ConvertExpensesWithNullAccessionNumbers = 1
			Select @TSQL += ' OR E.Accession is null' 
			
		Select @TSQL += '
		GROUP BY E.Chart, O.OrgR, E.AccountID, A.Org, PrincipalInvestigatorName
		HAVING sum(E.DividedAmount) <> 0
		)
		;'
		IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END				
		
-------------------------------------------------------------------------
COMMIT TRANSACTION
-------------------------------------------------------------------------
END
-------------------------------------------------------------------------
/*
CALLED BY:

DEPENDENCIES:
	
MODIFICATIONS:

[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.


--USAGE:	
	EXECUTE sp_Repopulate_AD419_219_Expenses

*/
