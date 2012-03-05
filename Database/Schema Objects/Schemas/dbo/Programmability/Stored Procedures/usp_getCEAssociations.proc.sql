-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/30/2006
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getCEAssociations] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     CESList.AccountPIName, Project.Project, CESXProjects.PctEffort
FROM         CESXProjects INNER JOIN
                      CESList ON CESXProjects.EID = CESList.EID INNER JOIN
                      Project ON CESXProjects.Accession = Project.Accession
ORDER BY CESList.AccountPIName

END
