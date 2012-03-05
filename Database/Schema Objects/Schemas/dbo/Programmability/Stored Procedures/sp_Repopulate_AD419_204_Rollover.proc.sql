-- =============================================
-- Author:		Scott Kirkland
-- Create date: 12/10/07
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_204_Rollover] 
(
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)

AS
BEGIN
	DECLARE @TSQL varchar(MAX) = null
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	--First remove '219' expenses
	Select @TSQL = 'DELETE FROM Expenses WHERE DataSource = ''219'''
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END				

	PRINT 'Inserting 219 expenses...'
	Select @TSQL ='INSERT INTO Expenses
		(DataSource, Chart, OrgR, Account, Expenses, isNonEmpExp, isAssociated, isAssociable, Org, Exp_SFN, FTE)
		(
		SELECT ''219'' DataSource, E.Chart, O.OrgR, E.AccountID, sum(E.Expenses) Expenses, 1, 0, 1, A.Org, ''219'' Exp_SFN, 0.00 FTE
		FROM [204AcctXProj] E
			LEFT JOIN FISDataMart.dbo.Accounts A ON 
				E.AccountID = A.Account
				AND E.Chart = A.Chart
				AND A.Year = @FiscalYear
				AND A.Period = ''--''
			LEFT JOIN Acct_SFN as SFN ON
				A.Account = SFN.Acct_ID
				AND  A.Chart = SFN.Chart
				AND SFN.SFN = ''204''
				AND A.Year = @FiscalYear
				AND A.Period = ''--''
			LEFT JOIN OrgXOrgR O ON
				A.Org = O.Org
				AND A.Chart = O.Chart
				AND A.Year = @FiscalYear
				AND A.Period = ''--''
		WHERE E.Accession IS NULL
		GROUP BY E.Chart, O.OrgR, E.AccountID, A.Org
		HAVING sum(E.Expenses) > 0
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

END
