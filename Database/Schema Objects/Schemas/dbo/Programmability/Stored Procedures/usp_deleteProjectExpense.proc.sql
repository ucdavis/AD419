-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_deleteProjectExpense] 
	-- Add the parameters for the stored procedure here
	@ExpenseID int

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Delete the association and then the expense itself

DELETE FROM Associations
WHERE     (ExpenseID = @ExpenseID)

DELETE FROM Expenses
WHERE     (ExpenseID = @ExpenseID)

/* -------- Old Expenses_CSREES version --------
DELETE FROM Expenses_CSREES
WHERE     (idExpense = @idExpense)
*/

END
