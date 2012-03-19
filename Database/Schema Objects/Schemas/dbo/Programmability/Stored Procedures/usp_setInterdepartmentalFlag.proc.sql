-- =============================================
-- Author:		Scott Kirkland
-- Create date: 10/06/06
-- Description:	This sproc will loop through the
-- Project tables and set any %XXX% project to have
-- its isInterdepartmental flage set to true.
-- Also, if a Projects is associated with the 
-- Interdepartmental OrgR/CRISDeptCd, set the flag
-- equal to true
-- =============================================
CREATE PROCEDURE [dbo].[usp_setInterdepartmentalFlag] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- First set the isInterdepartmental flag on any project with XXX in its name
UPDATE    Project
SET              isInterdepartmental = 1
WHERE     (Project LIKE '%XXX%')

-- Now set the flag on any project which is associated with the AINT department
UPDATE    Project
SET              isInterdepartmental = 1
FROM         Project INNER JOIN
                      ProjXOrgR ON Project.Accession = ProjXOrgR.Accession
WHERE     (ProjXOrgR.OrgR = 'AINT')

END
