-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	
-- =============================================
create PROCEDURE [dbo].[usp_get204ProjectsByDept] 
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

SELECT     P.Project, P.Accession
FROM         Project P INNER JOIN
                      ProjXOrgR ON P.Accession = ProjXOrgR.Accession
WHERE     (ProjXOrgR.OrgR LIKE @OrgR)
AND (P.Project NOT LIKE '%-H' AND P.Project NOT LIKE '%-RR' AND P.Project NOT LIKE '%-AH')
ORDER BY P.Project

END
