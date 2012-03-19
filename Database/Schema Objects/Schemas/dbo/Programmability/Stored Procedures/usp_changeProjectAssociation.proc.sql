-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_changeProjectAssociation] 
	-- Add the parameters for the stored procedure here
	@AccountID char(7),
	@Project varchar(24)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--First I will get the needed Accession number for the specified @Project
DECLARE @Accession char(7)

SET @Accession = (SELECT TOP 1  Accession
					FROM         Project
					WHERE     (Project = @Project) )

--Now set the @accession to the @Account
UPDATE    [204AcctXProj]
SET              Accession = @Accession
WHERE     (AccountID = @AccountID)

END
