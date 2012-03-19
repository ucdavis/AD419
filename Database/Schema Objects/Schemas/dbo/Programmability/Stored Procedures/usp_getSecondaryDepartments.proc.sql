-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getSecondaryDepartments] 
	-- Add the parameters for the stored procedure here
	@Accession char(7)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Get the code and friendly name for accession number

SELECT     Project.Accession, ReportingOrg.CRISDeptCd, ReportingOrg.OrgName AS deptname, ReportingOrg.IsActive
FROM         Project INNER JOIN
                      ProjXOrgR ON Project.Accession = ProjXOrgR.Accession INNER JOIN
                      ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
WHERE     (Project.Accession = @Accession) AND (ReportingOrg.IsActive = 1)

END
