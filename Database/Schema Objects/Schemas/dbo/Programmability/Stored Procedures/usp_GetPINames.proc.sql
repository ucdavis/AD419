-- =============================================
-- Author:		Alan Lai
-- Create date: 9/27/2006
-- Description:	Obtains a list of PIs for a specific department
--	using the Org code.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetPINames]

	@OrgR nvarchar(6)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

     SELECT DISTINCT PrincipalInvestigatorName, ORG.OrgR AS Org
	FROM FISDataMart.dbo.Accounts AS A INNER JOIN
	OrgXOrgR AS ORG ON ORG.Org = A.Org
    WHERE PrincipalInvestigatorName IS NOT NULL
			AND A.Chart = 'L'
			AND ORG.OrgR = @OrgR
			AND A.Year = 9999
			AND A.Period = '--'
	ORDER BY PrincipalInvestigatorName
	

END
