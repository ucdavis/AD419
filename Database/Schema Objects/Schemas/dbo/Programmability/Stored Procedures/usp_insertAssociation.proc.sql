-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertAssociation] 
	-- Add the parameters for the stored procedure here
	@ExpenseID int,
	@OrgR char(4),
	@Accession varchar(50),
	@Expenses float,
	@FTE float

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/* Simple insert of an association into the Associations table.  Don't do any
error checking becuase if there is a PK conflict we want it to raise an exception
so the transaction that this SPROC is called from will be aborted */
INSERT INTO Associations
                      (ExpenseID, OrgR, Accession, Expenses, FTE)
VALUES     (@ExpenseID,@OrgR,@Accession,@Expenses,@FTE)

UPDATE    Expenses
SET              isAssociated = 1
WHERE     (ExpenseID = @ExpenseID) AND (OrgR = @OrgR)

END
