-- =============================================
-- Author:		Ken Taylor
-- Create date: August 15, 2017
-- Description:	This procedure uses the PI_OrgR_Accession table to
--	repopulate the AllProjects, and Project table's IsInterdepartmental flag.
--
-- Usage: 
/*

	USE AD419
	GO

	EXEC [dbo].[usp_SetIsInterdepartmentalFlag] 
		@FiscalYear = 2016,
		@IsDebug = 0

	GO

*/
-- Modifications: 
--20181109 by kjt: Added header above Interdepartmental select statement
-- so we'd know what we're looking at when it's printed out.
--
-- Note that the AllProjectsNew and PI_OrgR_Accession tables have to be loaded first
-- before running this script.
--  
-- =============================================
CREATE PROCEDURE [dbo].[usp_SetIsInterdepartmentalFlag] (
	@FiscalYear int = 2016,
	@IsDebug bit = 0 
)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL varchar(max) = ''

	SELECT @TSQL = '
	-- First clear all of the IsInterdepartmental flags:
	UPDATE    AllProjectsNew
	SET       IsInterdepartmental = 0

	-- Second set the IsInterdepartmental flag for any project 
	-- with IsInterdepartmental = 1 in the PI_OrgR_Accession table:
	UPDATE    AllProjectsNew
	SET       IsInterdepartmental = 1
	WHERE     AccessionNumber IN (
		SELECT DISTINCT Accession
		FROM PI_OrgR_Accession
		WHERE IsInterdepartmental = 1
	)

	-- Do the same thing for the Project table:
	UPDATE    Project
	SET       IsInterdepartmental = 0

	UPDATE    Project
	SET       IsInterdepartmental = 1
	WHERE     Accession IN (
		SELECT DISTINCT Accession
		FROM PI_OrgR_Accession
		WHERE IsInterdepartmental = 1
	)
'
	PRINT @TSQL
	IF @IsDebug <> 1
	BEGIN
		EXEC (@TSQL)
		SELECT 'These are the Interdepartmental Projects:' AS Header
		SELECT * FROM AllProjectsNew 
		WHERE IsInterdepartmental = 1 
	END

END