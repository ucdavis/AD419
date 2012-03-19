------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_204_Expenses
BY:	Mike Ransom
DESCRIPTION: 

CURRENT STATUS:
[11/6/06] Mon
	Completely re-written.  Working properly.

TODO:

NOTES:

--USAGE:	
	EXECUTE sp_Repopulate_AD419_204_Expenses

DEPENDENCIES:
	Table 204AcctXProj needs to be populated with the 204 expenses from the FIS/PPS extracts
	Then the "204" data entry performed to associate the expense's Accounts to projects (204AcctXProj.Accession entered in UI).

MODIFICATIONS: see bottom
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_204_Expenses](
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
-------------------------------------------------------------------------
BEGIN
	DECLARE @TSQL varchar(MAX) = null

-------------------------------------------------------------------------
--Insert 
	--(126 row(s) affected)

	--Note: In order to generate the final Associations, there needs to be some way of identifying specific rows from the Expenses_CSREES table so that the Accession number can be associated with the expense.  Expenses_CSREES.PK, the PK, is the only unique identifying value.  I decided that the best thing to do would be to put this value in the AD419_Expenses_Dataset.Sub_Acct column, since it isn't used in the final dataset.

	--This insert *doesn't* aggregate any expenses, as these specific expenses are already specifically associated with projects.

	--Accession NOT NULL is used, since not all rows are associated with projects.  The expense records include many against state-wide projects that we don't report on

	--None of the info for Account,subaccount, EID, Name,PI, etc. is needed, as that info is only used to aid the manual associations.  (Yipee!)
	
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
	--Delete all FIS-sourced expense records:
	PRINT '--DELETE FROM Associations WHERE DataSource = ''204''...'
	Select @TSQL = 'DELETE FROM Associations WHERE ExpenseID in (
				SELECT ExpenseID FROM AllExpenses WHERE DataSource = ''204''
			);'	
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END		
			
	PRINT '--DELETE FROM AllExpenses WHERE DataSource = ''204''...'
	Select @TSQL = 'DELETE FROM AllExpenses WHERE DataSource = ''204''
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
	--Insert adjusted expenses from FIS.  (from udf_Adjusted_FIS_Expenses())
		-- udf_Adjusted_FIS_Expenses() produces a dataset that's a UNION of FIS expenses + FIS Reversals.
		--  The sign of the "reversal" amounts are changed in the UDF so that they can be SUMmed here.
	PRINT '--Inserting 204 AllExpenses...'
	-- This will insert a single record each account/expense entry.
	Select @TSQL = 'INSERT INTO AllExpenses
		(DataSource, Chart, OrgR, Account, Expenses, isNonEmpExp, isAssociated, isAssociable, Org, Exp_SFN)
		(
		SELECT distinct ''204'' DataSource, E.Chart, O.OrgR, E.AccountID, sum(E.DividedAmount) Expenses, 1, 1, 0, A.Org, ''204'' Exp_SFN
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
		WHERE E.Accession IS NOT NULL AND IsCurrentProject = 1 AND (Is219 is null or Is219 = 0) 
		GROUP BY E.Chart, O.OrgR, E.AccountID, A.Org
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
	
/*
Next we have to insert one or more records for a single account where we've split the expense across
multiple projects having the same PI.

For this step, we should have an entry for every accession/expense record where the accession is not null
and the is219 is != 1, and IsCurrentProject != 0

for each of these records, we want to insert a record into the associations table, and
set the OrgR to the Project's OrgR, and the expenseID to the AllExpenses.ExpenseID.

Therefore, to find the expense record is should be something like
select Account, ExpenseID, OrgR
from AllExpenses
where datasource = '204'

for each entry in this result set, fetch the entries from 204AcctXProj where the account matches, and 
insert them into the associations table
*/	
Select @TSQL = 'declare MyCursor CURSOR for select Account, ExpenseID, OrgR
from AllExpenses
where datasource = ''204'';

declare @MyAccount varchar(7), @MyExpenseID int, @MyOrgR varchar(4)

 declare @MyAssociationsTable TABLE ([ExpenseID] int
           ,[OrgR] varchar(4)
           ,[Accession] varchar(50)
           ,[Expenses] float
           ,[FTE] float)

open MyCursor

fetch MyCursor into @MyAccount, @MyExpenseID, @MyOrgR

while @@FETCH_STATUS <> -1

begin

    -- get the 204 records for the corresponding records
           
    insert into @MyAssociationsTable  ([ExpenseID]
           ,[OrgR]
           ,[Accession]
           ,[Expenses]
           ,[FTE])
    SELECT @MyExpenseID ExpenseID, 
		   @MyOrgR OrgR, 
		   AcctXProj.Accession, 
		   AcctXProj.DividedAmount Expenses, 
		   0.0 as FTE 
		FROM [204AcctXProj] AcctXProj
		WHERE AcctXProj.AccountID = @MyAccount
    
	fetch MyCursor into @MyAccount, @MyExpenseID, @MyOrgR

end

close MyCursor
deallocate MyCursor

	-- Insert 204 associations:
	PRINT ''--Inserting 204 associations...''
	INSERT INTO [AD419].[dbo].[Associations]
           ([ExpenseID]
           ,[OrgR]
           ,[Accession]
           ,[Expenses]
           ,[FTE])
	(
		SELECT 
			[ExpenseID]
           ,[OrgR]
           ,[Accession]
           ,[Expenses]
           ,[FTE]
		FROM @MyAssociationsTable ) order by ExpenseID
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
[12/6/05] Tue	
	Started. Finished.
[11/6/06] Mon
	Completely re-written. Table and column names, structure all changed.
	* Inserts directly into final Expenses table now.
	
[12/17/2010] by kjt:
	Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.

--USAGE:	
	EXECUTE sp_Repopulate_AD419_204_Expenses

*/
