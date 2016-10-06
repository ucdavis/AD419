------------------------------------------------------------------------
/*
PROGRAM: sp_Repopulate_AD419_FIS_Expenses
BY:	Ken Taylor

DESCRIPTION: 

DELETE all Associations where ExpenseId related with an Expense with a DataSource of "FIS"
DELETE all Expenses with a DataSource of "FIS"
Insert all expenses from the FIS_ExpensesForNon204Projects
WHERE SFN NOT BETWEEN '201' AND '205'

--USAGE:	
	EXECUTE sp_Repopulate_AD419_FIS_Expenses @FiscalYear = 2015, @IsDebug = 0, @TableName = 'AllExpensesNew'
MODIFICATIONS: 
*/

-------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_FIS_Expenses] (
@FiscalYear int = 2015,
@IsDebug bit = 0,
@TableName varchar(100) = 'AllExpenses'
)
AS

BEGIN

declare @TSQL varchar(MAX) = null

-- First check if their are any expense without OrgRs:
	BEGIN
		DECLARE @NumBlankOrgs int = 0
		SELECT @NumBlankOrgs = (SELECT COUNT(*) 
		FROM FIS_ExpensesForNon204Projects
		WHERE OrgR IS NULL)
		IF @NumBlankOrgs > 0
		BEGIN 
			PRINT '-- Not all FIS Expenses have OrgR assigned.  Assign departments beore proceeding!'
			RETURN 
		END
	END
-------------------------------------------------------------------------
BEGIN TRANSACTION
-------------------------------------------------------------------------
	--Delete all FIS-sourced expense records:
	PRINT '--DELETE FROM ' + @TableName + ' WHERE DataSource = ''FIS''...'
	Select @TSQL = 'DELETE FROM ' + @TableName + ' WHERE DataSource = ''FIS''; '
	
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
-------------------------------------------------------------------------
	
	PRINT '--Inserting FIS expenses...'
	
	Select @TSQL= '
	INSERT INTO ' + @TableName + '
		(
		DataSource,
		Chart,
		OrgR,
		Account,
		SubAcct,
		Expenses,
		isNonEmpExp,
		EID,
		Employee_Name,
		isAssociated,
		isAssociable,
		PI_Name,
		Org,
		Exp_SFN,
		Sub_Exp_SFN
		)
		(
		SELECT 
			''FIS'',
			E.Chart,
			E.OrgR Org_R,
			E.Account,
			SubAccount,
			sum(ExpenseSum)	Expenses,
			1	isNonEmpExp,
			NULL	EID,
			NULL	Employee_Name,
			0	isAssociated,
			1	isAssociable,
			PrincipalInvestigator	PI_Name,
			E.Org,
			E.SFN Exp_SFN	,
			E.SFN Sub_Exp_SFN
		FROM FIS_ExpensesForNon204Projects E

		WHERE 
			LEFT(SFN,3) NOT BETWEEN ''201'' AND ''205'' 
		GROUP BY E.chart, OrgR, E.Account, SubAccount, PrincipalInvestigator, A.Org, LEFT(SFN,3)
		HAVING sum(ExpenseSum) <> 0
		)
		
-- I think we want to perform a check for this first and have the Org updated or the expense excluded
--DELETE FROM ' + @TableName + '
--WHERE     (OrgR IS NULL) AND DataSource = ''FIS''

UPDATE    ' + @TableName + '
SET              SubAcct = NULL
WHERE     (SubAcct = ''-----'') AND DataSource = ''FIS''

UPDATE    ' + @TableName + '
SET              FTE = 0
WHERE     (FTE IS NULL) AND DataSource = ''FIS''

UPDATE    ' + @TableName + '
SET              FTE_SFN = ''244'', Staff_Grp_Cd = ''Other''
WHERE     (Staff_Grp_Cd IS NULL) AND DataSource = ''FIS'' 
;'

	IF @IsDebug = 1
		BEGIN
			SET NOCOUNT ON
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
