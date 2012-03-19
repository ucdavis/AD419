-- =============================================
-- Author:		Scott Kirkland
-- Create date: 10/17/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_deleteAssociationsByGrouping] 
	-- Add the parameters for the stored procedure here
	@OrgR char(4),
	@Grouping varchar(50),
	@Chart char(2),
	@Criterion varchar(50)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- The string '----' is the code for a null entry
DECLARE @isCriterionNull bit
IF @Criterion = '----'
	SET @isCriterionNull = 1
ELSE IF @Criterion = ''
	SET @isCriterionNull = 1
ELSE
	SET @isCriterionNull = 0

/* By PI */
IF @Grouping = 'PI'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			-- First set the isAssociated flag = 0, then delete the associations
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID
			WHERE     (Associations.OrgR = Associations.OrgR) AND (Expenses.PI_Name IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
							  Expenses ON Associations.ExpenseID = Expenses.ExpenseID
			WHERE     (Associations.OrgR = Associations.OrgR) AND (Expenses.PI_Name IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			-- First set the isAssociated flag = 0, then delete the associations
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID
			WHERE     (Associations.OrgR = Associations.OrgR) AND (Expenses.PI_Name = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
							  Expenses ON Associations.ExpenseID = Expenses.ExpenseID
			WHERE     (Associations.OrgR = Associations.OrgR) AND (Expenses.PI_Name = @Criterion) AND (Expenses.Chart = @Chart)
		END
END

/* By Organization */
ELSE IF @Grouping = 'Organization'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID LEFT OUTER JOIN
								  FISDataMart.dbo.Organizations AS O ON Expenses.Org = O.Org
								  AND O.Year = 9999 AND O.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
							  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
							  Project ON Associations.Accession = Project.Accession LEFT OUTER JOIN
								  FISDataMart.dbo.Organizations AS O ON Expenses.Org = O.Org
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  FISDataMart.dbo.Organizations AS O ON Expenses.Org = O.Org
								   AND O.Year = 9999 AND O.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
							  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
							  Project ON Associations.Accession = Project.Accession INNER JOIN
								  FISDataMart.dbo.Organizations AS O ON Expenses.Org = O.Org
								  AND O.Year = 9999 AND O.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (O.Org = @Criterion) AND (Expenses.Chart = @Chart)
		END
END

/* By Sub-Account */
ELSE IF @Grouping = 'Sub-Account'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID LEFT OUTER JOIN
								  FISDataMart.dbo.SubAccounts AS SA ON Expenses.SubAcct = SA.SubAccount AND SA.Year = 9999 AND SA.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.SubAcct IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM         Associations
			FROM			Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession LEFT OUTER JOIN
								  FISDataMart.dbo.SubAccounts AS SA ON Expenses.SubAcct = SA.SubAccount
								  AND SA.Year = 9999 AND SA.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND ( Expenses.SubAcct IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  FISDataMart.dbo.SubAccounts AS SA ON Expenses.SubAcct = SA.SubAccount AND SA.Year = 9999 AND SA.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.SubAcct = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM         Associations
			FROM			Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession INNER JOIN
								  FISDataMart.dbo.SubAccounts AS SA ON Expenses.SubAcct = SA.SubAccount
								  AND SA.Year = 9999 AND SA.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND ( Expenses.SubAcct = @Criterion ) AND (Expenses.Chart = @Chart)
		END
END

/* By Account */
ELSE IF @Grouping = 'Account'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID LEFT OUTER JOIN
								  FISDataMart.dbo.Accounts AS A ON Expenses.Account = A.Account
								  AND A.Year = 9999 AND A.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.Account IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession LEFT OUTER JOIN
								  FISDataMart.dbo.Accounts AS A ON Expenses.Account = A.Account	
								  AND A.Year = 9999 AND A.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.Account IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  FISDataMart.dbo.Accounts AS A ON Expenses.Account = A.Account
								  AND A.Year = 9999 AND A.Period = '--'
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.Account = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession INNER JOIN
								  FISDataMart.dbo.Accounts AS A ON Expenses.Account = A.Account
								  AND A.Year = 9999 AND A.Period = '--'	
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.Account = @Criterion) AND (Expenses.Chart = @Chart)
		END

END

/* By Employee */
ELSE IF @Grouping = 'Employee'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.EID IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.EID IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.EID = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.EID = @Criterion) AND (Expenses.Chart = @Chart)
		END
	
END

ELSE IF @Grouping = 'None'
BEGIN
	IF @isCriterionNull = 1
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations LEFT OUTER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.ExpenseID IS NULL) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations LEFT OUTER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.ExpenseID IS NULL) AND (Expenses.Chart = @Chart)
		END
	ELSE
		BEGIN
			UPDATE    Expenses
			SET              isAssociated = 0
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.ExpenseID = @Criterion) AND (Expenses.Chart = @Chart)

			DELETE FROM Associations
			FROM         Associations INNER JOIN
								  Expenses ON Associations.ExpenseID = Expenses.ExpenseID INNER JOIN
								  Project ON Associations.Accession = Project.Accession
			WHERE     (Associations.OrgR = @OrgR) AND (Expenses.ExpenseID = @Criterion) AND (Expenses.Chart = @Chart)
		END
	
END

END
