-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_insertSecondaryDepartments] 
	-- Add the parameters for the stored procedure here
	@Accession char(7), 
	@CRISDeptCd char(4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- First get the OrgR associated with this CRIS_DeptCd
DECLARE @OrgR char(4)
SET @OrgR = ( SELECT     OrgR
				FROM         ReportingOrg
				WHERE     (isActive = 1) AND (CRISDeptCd = @CRISDeptCd)  )

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
