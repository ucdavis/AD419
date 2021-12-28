-- =============================================
-- Author:		Ken Taylor
-- Create date: August 9, 2017
-- Description:	Get a list of Admin Orgs which are to be 
-- excluded for the purose of prorating expenses, etc.
-- Note that these are the OrgRs that do not need to
-- have their expenses associated prior to creating
-- the final reports, etc.
-- Usage:
/*

USE AD419
GO

SELECT * FROM dbo.udf_GetOrgRExclusions()


*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_GetOrgRExclusions 
()
RETURNS 
@OrgRExclusions TABLE 
(
	OrgR varchar(4)
)
AS
BEGIN
	INSERT INTO @OrgRExclusions VALUES ('ADNO');
	-- This will get any additional admin clusters like ACL1-ACL5:
	INSERT INTO @OrgRExclusions 
	SELECT [OrgR] 
	FROM [dbo].[ReportingOrg] 
	WHERE [IsAdminCluster] = 1 AND [IsActive] = 1;
	
	RETURN 
END