-- =============================================
-- Author:		Alan Lai
-- Create date: 10/17/2006
-- Description:	Gets a list of Reporting Orgs
--	that the user is allowed to see based on their
--	associations in CatBert.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetReportingOrgByUserByEmployeeID] 
	
	@EmployeeID nvarchar(9),
	@ApplicationName varchar(50) = 'AD419'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	SELECT     OrgR, OrgR + '  (' + RTRIM(OrgName) + ')' AS [Org-Dept]
	FROM         ReportingOrg
	WHERE     (isActive = 1)
		AND OrgR IN (SELECT FIS_Code FROM udf_GetUserUnitsForApplication(@EmployeeID, @ApplicationName))
	ORDER BY OrgR

END
