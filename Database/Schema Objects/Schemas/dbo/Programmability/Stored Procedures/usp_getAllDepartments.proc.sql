-- =============================================
-- Author:		Scott Kirkland
-- Create date: 9/15/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[usp_getAllDepartments] 
	-- Add the parameters for the stored procedure here

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT     CRISDeptCd, OrgName AS deptname
FROM         ReportingOrg
WHERE     (isActive = 1)
ORDER BY deptname ASC

END
