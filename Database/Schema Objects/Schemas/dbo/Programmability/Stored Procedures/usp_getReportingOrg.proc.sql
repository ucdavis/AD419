-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getReportingOrg] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     OrgR, OrgR + '  (' + RTRIM(OrgName) + ')' AS [Org-Dept]
FROM         ReportingOrg
WHERE     (isActive = 1)
ORDER BY OrgR


END
