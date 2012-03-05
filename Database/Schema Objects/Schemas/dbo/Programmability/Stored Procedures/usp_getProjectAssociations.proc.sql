-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/18/06
-- Description:	Get the 204 project expenses.
-- Modified: 
-- 2010/03/02 by Ken Taylor: Added logic to exclude 219 or expired project expenses.
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

SELECT E.pk, E.Chart, E.AccountID, Cast(E.Expenses AS decimal(16,2)) AS Expenses, A.AccountName, 
		A.AwardNum, A.PrincipalInvestigatorName, P.Project, P.TermDate
FROM  [204AcctXProj] AS E 
		LEFT JOIN Project AS P ON E.Accession = P.Accession
		LEFT JOIN FISDataMart.dbo.Accounts AS A ON E.AccountID = A.Account AND E.Chart = A.Chart AND A.Year = 9999 AND A.Period = '--'
		LEFT JOIN [OrgXOrgR] AS O ON A.Org = O.Org AND A.Chart = O.Chart
WHERE O.OrgR like @OrgR AND (E.Is219 is NULL AND (E.IsCurrentProject = 1 OR E.IsCurrentProject is null))
ORDER BY A.PrincipalInvestigatorName, P.Project

END
