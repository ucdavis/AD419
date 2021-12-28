
-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	Get the 204 project expenses.
-- Usage:
/*
	EXEC [dbo].[usp_getProjectAssociations]  @OrgR = 'AIND'

*/
-- Modified: 
-- 2010/03/02 by Ken Taylor: Added logic to exclude 219 or expired project expenses.
-- 2015-12-03 by kjt: Revised to allow is219 null or 0.
-- 2020-11-24 by kjt: Changed join to use OrgR Vs Org.
-- =============================================
CREATE PROCEDURE [dbo].[usp_getProjectAssociations] 
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

SELECT DISTINCT E.pk, E.Chart, E.AccountID, Cast(E.Expenses AS decimal(16,2)) AS Expenses, A.AccountName, 
		A.AwardNum, A.PrincipalInvestigatorName, P.Project, P.TermDate
FROM  [204AcctXProj] AS E 
		LEFT JOIN Project AS P ON E.Accession = P.Accession
		LEFT JOIN [OrgXOrgR] AS O ON E.OrgR = O.OrgR AND E.Chart = O.Chart
		LEFT JOIN FISDataMart.dbo.Accounts A ON E.AccountID = A.Account AND E.Chart = A.Chart  AND A.Year = 9999 AND A.Period = '--'
WHERE E.OrgR like @OrgR AND ((E.Is219 is NULL OR E.Is219 = 0) AND (E.IsCurrentProject = 1 OR E.IsCurrentProject is null))
ORDER BY A.PrincipalInvestigatorName, P.Project

END

update [204AcctXProj] set Is219 = null where Is219 = 0
