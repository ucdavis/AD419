-- =============================================
-- Author:		Ken Taylor
-- Create date: September 10, 2019
-- Description:	Update the Orgs and Orgrs on all Associations and 
--	Expenses for the accounts which have potentially the wrong closed 
--	OrgRs (and Orgs).
--
-- Usage:
/*
	USE [AD419]
	GO

	EXEC usp_UpdateAssociationsForAccountsWithTheWrongClosedOrgRs 

*/
-- Modifications:
--
-- =============================================
CREATE PROCEDURE usp_UpdateAssociationsForAccountsWithTheWrongClosedOrgRs 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2019, -- Dummy parameter to keep all the method signatures the same.
	@IsDebug bit = 0 -- Set to 1 to print generated SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	/*
	Update all of the Expanses OrgR and Org having AD419Accounts.HaveOrgsBeenAdjusted IS NOT NULL, 
	meaning their KFS OrgR is different from their most recent non-closed OrgR, and has been
	reviewed.  Also update the corresponding associations for those Expenses' identified above. 	
	*/

	DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	UPDATE AllExpenses
	SET OrgR = t2.OrgR, Org = t2.Org
	FROM AllExpenses t1
	INNER JOIN AD419Accounts t2 ON t1.Chart = t2.Chart AND t1.Account = t2.Account
	WHERE t2.HaveOrgsBeenAdjusted IS NOT NULL

	UPDATE Associations
	SET OrgR = t2.OrgR
	FROM Associations t1
	INNER JOIN Expenses t2 ON t1.ExpenseID = t2.ExpenseID
	INNER JOIN AD419Accounts t3 ON t2.Chart = t3.Chart AND t2.Account = t3.Account
	WHERE t3.HaveOrgsBeenAdjusted IS NOT NULL
'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL) 

END