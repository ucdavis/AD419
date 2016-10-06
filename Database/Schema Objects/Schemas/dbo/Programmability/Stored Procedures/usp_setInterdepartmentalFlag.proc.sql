-- =============================================
-- Author:		Scott Kirkland
-- Create date: 10/06/06
-- Description:	This sproc will loop through the
-- Project tables and set any %XXX% project to have
-- its isInterdepartmental flage set to true.
-- Also, if a Projects is associated with the 
-- Interdepartmental OrgR, set the flag
-- equal to true
--
-- Usage: 
/*
	EXEC [dbo].[usp_setInterdepartmentalFlag] 
*/
-- Modifications: 
--	2016-06-07 by kjt: Revised to use the AllProjectsNew
--	2016-08-18 by kjt: Added OrgR "XXXX" to inclusion list, plus renamed to usp_setInterdepartmentalFlag.
--
-- Note that the AllProjectsNew and ProjXOrgR tables have to be loaded first
-- before running this script. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_setInterdepartmentalFlag] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- First set the isInterdepartmental flag on any project with XXX in its name
	UPDATE    AllProjectsNew
	SET              isInterdepartmental = 1
	WHERE     (ProjectNumber LIKE '%XXX%')

	-- Now set the flag on any project which is associated with the AINT department
	UPDATE    AllProjectsNew
	SET              isInterdepartmental = 1
	FROM         AllProjectsNew Project INNER JOIN
						  ProjXOrgR ON Project.AccessionNumber = ProjXOrgR.Accession
	WHERE     (ProjXOrgR.OrgR IN ('AINT', 'XXXX'))

	UPDATE AllProjectsNew
	SET IsInterdepartmental = 0
	WHERE IsInterdepartmental IS NULL

END
