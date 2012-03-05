-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/27/2006
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_deleteAssociation] 
	-- Add the parameters for the stored procedure here
	@ExpenseID int,
	@OrgR char(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

DELETE FROM Associations
WHERE     (ExpenseID = @ExpenseID) AND (OrgR = @OrgR)

UPDATE    Expenses
SET              isAssociated = 0
WHERE     (ExpenseID = @ExpenseID) AND (OrgR = @OrgR)
	AND isAssociable = 1

END
