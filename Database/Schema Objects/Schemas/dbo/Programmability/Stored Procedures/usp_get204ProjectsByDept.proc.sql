-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	Returns a list of 204 projects for the Org provided;
-- or for all orgs if 'All' is provided.
-- Modifications:
--	2015-03-25 by kjt: Modified to use [204AcctXProj] and AllProjects tables Vs. Project and 
-- ProjXOrgR since the CG, OG and SG proijects will no longer be present in the Project table.
--  2015-10-29 by kjt: Revised back to use ProjXOrgR since 204 projects are now being included, plus also 
-- added DISTINCT so only single occurances will be returned.
-- =============================================
CREATE PROCEDURE [dbo].[usp_get204ProjectsByDept] 
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

SELECT  DISTINCT   P.Project, P.Accession
FROM         Project P INNER JOIN
                      ProjXOrgR ON P.Accession = ProjXOrgR.Accession
WHERE     (ProjXOrgR.OrgR LIKE @OrgR)
AND (P.Project NOT LIKE '%-H' AND P.Project NOT LIKE '%-RR' AND P.Project NOT LIKE '%-AH')
ORDER BY P.Project

END
