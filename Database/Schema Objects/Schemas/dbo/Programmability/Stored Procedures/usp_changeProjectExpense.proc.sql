-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_changeProjectExpense] 
	-- Add the parameters for the stored procedure here
	@ExpenseID int,
	@Expenses decimal(16,2)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- First update the expense, then the association
UPDATE    Expenses
SET              Expenses = @Expenses
WHERE     (ExpenseID = @ExpenseID)

UPDATE    Associations
SET              Expenses = @Expenses
WHERE     (ExpenseID = @ExpenseID)

/* ------- Old version -----------
UPDATE    Expenses_CSREES
SET              Expenses = @Expenses
WHERE     (idExpense = @idExpense)
*/

END
