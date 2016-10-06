-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/16/06
-- Description:	Truncate and reload the ProjXOrgR table with data present in
--	in the Project table and InterdepartmentalProjectsImport table.
--
-- NOTE: The AllProjects table and InterdepartmentalProjectsImport
-- must have already been loaded.
-- Usage:
/*
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgR]
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

*/
-- Modifications:
--	2010/01/13 by Ken Taylor: Revised to allow IsDebug and printing of SQL statements.
--	2016/08/04 by kjt: Revised to also include inserting any missing accession, OrgR 
--	that are not already in the ProjXOrgR table using the data present in the InterdepartmentalProjectsImport table. 
--	Also revised to use the OrgR directly from the Project view.
--	2016-08-18 by kjt: Revised to use the ProjectV
--	2016-08-19 by kjt: Revised to use udf_AllProjectsNewForFiscalYear, plus added param @FiscalYear
--	2016-08-19 by kjt: Revised to use udf_AD419ProjectsForFiscalYear, plus added param @FiscalYear
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjXOrgR] 
	@FiscalYear int = 2015,
	@IsDebug bit = 0 -- set to 1 to print SQL only
AS
BEGIN
	declare @TSQL varchar(max) = '' -- for holding SQL statement(s) to be executed.
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

-- Delete all non-interdepartmental projects that are in the project table
	Select @TSQL = 'DELETE FROM ProjXOrgR
	WHERE (Accession IN 
		(
			SELECT Project.Accession
			FROM   udf_AD419ProjectsForFiscalYear( ' +  CONVERT(varchar(4), @FiscalYear) +  ' ) Project
			WHERE Project.IsInterdepartmental = 0
		)
	);'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	

-- Add back in all projects not in the table
	Select @TSQL = 'INSERT INTO ProjXOrgR
	(
		Accession,
		OrgR
	)
	SELECT     Project.Accession Accession, Project.OrgR
	FROM       udf_AD419ProjectsForFiscalYear( ' +  CONVERT(varchar(4), @FiscalYear) +  ' )  Project 
	WHERE Project.Accession NOT IN 
		(
			SELECT Accession
			FROM   ProjXOrgR
		);'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
			
-- Clean any the interdepartmentals
Select @TSQL = 'DELETE FROM ProjXOrgR
WHERE OrgR IN (''XXXX'', ''AINT'');
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
