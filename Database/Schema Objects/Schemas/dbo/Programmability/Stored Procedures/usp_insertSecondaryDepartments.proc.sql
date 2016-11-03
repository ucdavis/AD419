-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	Insert a cooperating department for an interdepartmental project
-- Modifications:
--	2016-08-04 by kjt: Revised to use the OrgR provided in the projects table instead of resolving the OrgR via the CRISDeptCd.
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertSecondaryDepartments] 
	-- Add the parameters for the stored procedure here
	@Accession char(7), 
	@OrgR char(4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ProjXOrgCount int
	SET @ProjXOrgCount = (
							SELECT Count(OrgR) 
							FROM ProjXOrgR 
							WHERE (Accession = @Accession) AND (OrgR = @OrgR)
						  )

	IF @ProjXOrgCount <> 0
		RETURN -1

	-- Now insert the entry into the ProjXOrgR table
	INSERT INTO ProjXOrgR
						  (Accession, OrgR)
	VALUES     (@Accession,@OrgR)

END
