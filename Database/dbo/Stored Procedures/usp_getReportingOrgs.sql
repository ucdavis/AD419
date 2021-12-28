
-- =============================================
-- Author:		Scott Kirkland
-- Create date: 6/19/20
-- Description:
-- =============================================
CREATE PROCEDURE [dbo].[usp_getReportingOrgs]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     OrgR, OrgR + '  (' + RTRIM(OrgName) + ')' AS Name
FROM         ReportingOrg
WHERE     (isActive = 1)
ORDER BY OrgR


END