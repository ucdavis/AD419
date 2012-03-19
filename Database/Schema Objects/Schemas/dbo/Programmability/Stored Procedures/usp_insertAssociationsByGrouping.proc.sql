-- =============================================
-- Author:		Scott Kirkland
-- Create date: 10/25/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertAssociationsByGrouping] 
	-- Add the parameters for the stored procedure here
	@OrgR varchar(4),
	@Grouping varchar(50),
	@Chart char(2),
	@Criterion varchar(50),
	@Accession varchar(50),
	@Expense float,
	@FTE float
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DECLARE @CriterionNull bit
IF @Criterion = '----'
	SET @CriterionNull = 1
ELSE IF @Criterion = ''
	SET @CriterionNull = 1
ELSE
	SET @CriterionNull = 0

-- We are going to build up a table of ExpenseID's in the current grouping
DECLARE @txtSQL varchar(2000)

-- Insert all of the matching expenseIDs
SET @txtSQL =
	'
	DECLARE @tblExpenseIDs TABLE ( ExpenseID int )

	INSERT INTO @tblExpenseIDs
	SELECT     E.ExpenseID AS ExpenseID
	FROM         Expenses AS E
	WHERE     (E.OrgR = ''' + @OrgR + ''') AND (E.Chart = ''' + @Chart + ''')
	'
	+
	CASE @Grouping
		WHEN  'Organization' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.Org IS NULL )'
				WHEN 0 THEN
					' AND ( E.Org = ''' +@Criterion + ''')' 
			END
		WHEN 'Sub-Account' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.SubAcct IS NULL )'
				WHEN 0 THEN
					' AND ( E.SubAcct = ''' +@Criterion + ''')'
			END
		WHEN 'PI' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.PI_Name IS NULL )'
				WHEN 0 THEN
					' AND ( E.PI_Name = ''' +@Criterion + ''')'
			END		
		WHEN 'Account' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.Account IS NULL )'
				WHEN 0 THEN
					' AND ( E.Account = ''' +@Criterion + ''')'
			END
		WHEN 'Employee' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.EID IS NULL )'
				WHEN 0 THEN
					' AND ( E.EID = ''' +@Criterion + ''')'
			END
		WHEN 'None' THEN
			CASE @CriterionNull
				WHEN 1 THEN
					' AND ( E.ExpenseID IS NULL )'
				WHEN 0 THEN
					' AND ( E.ExpenseID = ''' +@Criterion + ''')'
			END
	END	
	+
	'
	INSERT INTO Associations
                      (ExpenseID, OrgR, Accession, Expenses, FTE)
	SELECT ExpenseID AS ExpenseID, '''+@OrgR+''' AS OrgR, '''+@Accession+''' AS Accession, '+CAST(@Expense AS varchar(50))+' AS Expenses, '+CAST(@FTE AS varchar(50))+' AS FTE
	FROM @tblExpenseIDs
	'
	+
	'
	UPDATE    Expenses
	SET              isAssociated = 1
	WHERE     Expenses.ExpenseID IN (SELECT ExpenseID FROM @tblExpenseIDs)
	'

EXEC (@txtSQL)

/*
-- Now insert into the associations table the association for each ExpenseID
INSERT INTO Associations
                      (ExpenseID, OrgR, Accession, Expenses, FTE)
SELECT ExpenseID AS ExpenseID, @OrgR AS OrgR, @Accession AS Accession, @Expense AS Expenses, @FTE AS FTE
FROM @tblExpenseIDs

-- Update the ExpenseID itself to mark the change
UPDATE    Expenses
SET              Expenses = @Expense, FTE = @FTE
WHERE     (OrgR = @OrgR) AND (Chart = @Chart) AND (Account = @Criterion)
				AND ( Expenses.ExpenseID IN (SELECT ExpenseID FROM @tblExpenseIDs) )
*/


END
