
-- =============================================
-- Author:		Scott Kirkland
-- Create date: 6/19/20
-- Description:	Gets a list of Reporting Orgss
--	that the user is allowed to see based on their
--	associations in CatBert.
-- =============================================
create PROCEDURE [dbo].[usp_GetReportingOrgsByUser]

	@LoginID nvarchar(10),
	@ApplicationName varchar(50) = 'AD419'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT     OrgR, OrgR + '  (' + RTRIM(OrgName) + ')' AS Name
	FROM         ReportingOrg
	WHERE     (isActive = 1)
		AND OrgR IN (SELECT FIS_Code FROM udf_GetUserUnitsForApplicationByLoginID(@LoginID, @ApplicationName))
	ORDER BY OrgR

END