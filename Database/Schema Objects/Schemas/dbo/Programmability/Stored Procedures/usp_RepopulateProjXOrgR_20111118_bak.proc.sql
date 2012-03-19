-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/16/06
-- Description:	
-- 2010/01/13 by Ken Taylor: Revised to allow IsDebug and printing of SQL statements.
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjXOrgR_20111118_bak] 
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
				FROM         Project INNER JOIN
						  ReportingOrg ON Project.CRIS_DeptID = ReportingOrg.CRISDeptCd
			WHERE Project.isInterdepartmental = 0
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
	SELECT     Project.Accession, ReportingOrg.OrgR
	FROM         Project INNER JOIN
						  ReportingOrg ON Project.CRIS_DeptID = ReportingOrg.CRISDeptCd
	WHERE Project.Accession NOT IN 
		(
			SELECT Accession
				FROM        ProjXOrgR
		);'
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END	
			
-- Clean up the interdepartmentals
Select @TSQL = 'DELETE FROM ProjXOrgR
WHERE OrgR = ''AINT'';
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
