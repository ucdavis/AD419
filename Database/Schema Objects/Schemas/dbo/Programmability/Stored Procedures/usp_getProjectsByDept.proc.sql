-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- Modifications:
-- 2010-10-28 by kjt: Added check for isValid to where clause.
-- 2011-11-10 by kjt: Added select distinct because some interdepartmental projects were
-- getting piched up twice.
CREATE PROCEDURE [dbo].[usp_getProjectsByDept] 
	-- Add the parameters for the stored procedure here
	@OrgR varchar(4)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

IF @OrgR = 'All'
BEGIN
	SET @OrgR = '%'
END

SELECT     DISTINCT Project.Project, Project.Accession
FROM         Project INNER JOIN
                      ProjXOrgR ON Project.Accession = ProjXOrgR.Accession
WHERE     (ProjXOrgR.OrgR LIKE @OrgR) AND isValid = 1
ORDER BY Project.Project

END
