-- =============================================
-- Author:		Scott Kirkland
-- Create date: 12/05/06
-- Description:	GIven the OrgR provided (or 'All' for all OrgRs) return a count of Expired, and non-Expired, i.e., Active, projects.
--
-- Usage:
/*
	EXEC [dbo].[usp_getActiveProjectsCount] @OrgR = 'All' -- For all projects;

	EXEC [dbo].[usp_getActiveProjectsCount] @OrgR = 'AANS' --For AANS projects only 
*/
--
-- Modifications:
-- 2010-10-28 by kjt: Revised where clause to include check for Project.IsValid.
-- 2016-08-13 by kjt: Revised to use Project's OrgR instead of CRIS deptID lookup.
-- 2016-08-15 by kjt: Note that we will no longer be associating expenses for 
--		expired projects in the AD-419 application, so this count should always be zero (0).
-- =============================================
CREATE PROCEDURE [dbo].[usp_getActiveProjectsCount_with_OrgR_mod] 
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

--SELECT  'Expired' AS ProjectStatus, 0 AS StatusCount
SELECT  'Expired' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM    Project --INNER JOIN
                --	ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE StatusCd = 'E' AND OrgR LIKE @OrgR AND Project.isValid = 1

UNION

SELECT 'Active' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM	Project --INNER JOIN
                --    ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE StatusCd <> 'E' AND OrgR LIKE @OrgR AND Project.isValid = 1

UNION

SELECT 'Total' AS ProjectStatus, COUNT(StatusCd) AS StatusCount
FROM	Project --INNER JOIN
                --   ReportingOrg AS R ON Project.CRIS_DeptID = R.CRISDeptCd
WHERE OrgR LIKE @OrgR AND Project.isValid = 1

END