


-- =============================================
-- Author:		Ken Taylor
-- Create date: August 15, 2017
-- Description:	Truncate and reload the ProjXOrgR table with data present
--	in the Project table and PI_OrgR_Accession table.
--
-- NOTE: The AllProjects table and PI_OrgR_Accession table
-- must have already been loaded.
--
-- This procedure populates records for both interdepartmental and 
--	non-interdepartmental projects, i.e. all Projects.
--
-- Usage:
/*

USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgR_v2]
		@FiscalYear = 2021,
		@IsDebug = 1

--SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	20201118 by kjt: Revised to use udf_AD419ProjectsForFiscalYearWithIgnored Vs.
--		udf_AD419ProjectsForFiscalYear as certain projects may have already been hidden.
--	20211116 by kjt: Added DISTINCT because duplicate projects were being returned.
--	20211120 by kjt: Actually, we want certain 204 projects to be hidden, so I'm adding
--		"WHERE isIgnored = 0" to the where clause as we were prorating expenses across projects
--		that should have had zero (0) expenses.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjXOrgR_v2] 
	@FiscalYear int = 2020,
	@IsDebug bit = 0 -- set to 1 to print SQL only
AS
BEGIN
	declare @TSQL varchar(max) = '' -- for holding SQL statement(s) to be executed.
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Delete all records present in the ProjXOrgR table:
	Select @TSQL = '
	TRUNCATE TABLE ProjXOrgR;
'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

-- Repopulate the table:
	Select @TSQL = '
	INSERT INTO ProjXOrgR
	(
		Accession,
		OrgR
	)
	SELECT     DISTINCT Project.Accession Accession, PIO.OrgR
	FROM       [dbo].[udf_AD419ProjectsForFiscalYearWithIgnored]( ' +  CONVERT(varchar(4), @FiscalYear) +  ' )  Project 
	INNER JOIN dbo.PI_OrgR_Accession PIO ON Project.Accession = PIO.Accession
	WHERE IsIgnored IS NULL OR IsIgnored = 0; -- Don''t include hidden projects.
'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
			
END