-- =============================================
-- Author:		Scott Kirkland
-- Create date: 12/05/06
-- Description:	
-- Modifications:
-- 2010-10-28 by kjt: Revised where clause to include check for Project.IsValid.
-- =============================================
CREATE PROCEDURE [dbo].[usp_getActiveProjectsCount] 
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

SELECT  'Expired' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM    Project INNER JOIN
                    ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE StatusCd = 'E' AND R.OrgR LIKE @OrgR AND Project.isValid = 1

UNION

SELECT 'Active' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM	Project INNER JOIN
                    ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE StatusCd <> 'E' AND R.OrgR LIKE @OrgR AND Project.isValid = 1

UNION

SELECT 'Total' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM	Project INNER JOIN
                    ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE R.OrgR LIKE @OrgR AND Project.isValid = 1

END
