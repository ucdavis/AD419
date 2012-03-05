-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_deleteSecondaryDepartment] 
	-- Add the parameters for the stored procedure here
	@Accession char(7),
	@CRISDeptCd char(4)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Select all Projects by Accession in the CRISDeptCd that are associated through the
-- 204_Acct_Prog_Asso table
SELECT     P.Project
FROM         ReportingOrg INNER JOIN
                      OrgXOrgR AS O ON ReportingOrg.OrgR = O.OrgR RIGHT OUTER JOIN
                      [204AcctXProj] AS E LEFT OUTER JOIN
                      Project AS P ON E.Accession = P.Accession LEFT OUTER JOIN
                      FISDataMart.dbo.Accounts AS A ON E.AccountID = A.Account AND E.Chart = A.Chart ON O.Org = A.Org AND O.Chart = A.Chart
                      AND A.Period = '--' AND A.Year = 9999
WHERE     (E.Accession = @Accession) AND (ReportingOrg.CRISDeptCd = @CRISDeptCd) AND (ReportingOrg.IsActive = 1)

-- If there were any associated projects, then we can't allow the delete to continue
IF @@ROWCOUNT <> 0
	RETURN -1

-- If there were not any associated project, then delete the projXOrgR relationship
DELETE FROM ProjXOrgR
FROM         ProjXOrgR INNER JOIN
                      ReportingOrg ON ProjXOrgR.OrgR = ReportingOrg.OrgR
WHERE     (ProjXOrgR.Accession = @Accession) AND (ReportingOrg.CRISDeptCd = @CRISDeptCd)

END
