-- =============================================
-- Author:		Ken Taylor
-- Create date: November 12, 2013
-- Description:	Replaces manual association of Interdepartmental projects 
-- to departments in ProgXOrgR using InterdepartmentProjectsImport table.
--
-- NOTE: Make load InterdepartmentProjectsImport table prior to running!!!!!
--
-- Usage:
/*
-- For testing:
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects]
		@FiscalYear = 2016, @DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1,  --1 to emulate deleting existing records; 0 to show SQL that would actually be run in non-debug mode.
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

-- For production:
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects]
		@FiscalYear = 2015, @DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1,
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
--	2015-03-31 by kjt: Removed any [AD419] database specific references so that this sproc can be used with other databases
--		such as [AD419_2014], etc.
--	2016-08-04 by kjt: Revised to use InterdepartmentProjectsImport table. 
--	2016-08-13 by kjt: Added sanity check to make sure all interdepartmental projects had their OrgRs identified.
--	2016-08-18 by kjt: Revised to use ProjectV
--	2016-08-20 by kjt: Revised to use udf_AD419ProjectsForFiscalYear as ProjectV was excluding 23 valid projects.
--	2016-11-07 by kjt: Added leading zero padding of accession number join against import table.
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects] 
	@FiscalYear int = 2015, -- This is the current AD-419 Reporting Period.
	@DeleteExistingInterdepartmentalProjectsFromProjXOrgR bit = 1, --Set to 0 to keep existing ID ProgXOrgR records.
	@IsDebug bit = 0  --Set to 1 to print SQL only.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL nvarchar(MAX) = ''

	SELECT @TSQL = '
	DELETE FROM [dbo].[ProjXOrgR]
	WHERE Accession IN (
		SELECT DISTINCT Accession 
		FROM [dbo].udf_AD419ProjectsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ')
		WHERE IsInterdepartmental = 1
	)
'
	IF @DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1
	BEGIN
		IF @IsDebug = 1
			PRINT @TSQL
		ELSE
			EXEC(@TSQL)
	END

	DECLARE @CoopDeptsTable TABLE (Accession varchar(50), Project varchar(50), NumDepts int, OrgR varchar(4))

	INSERT INTO @CoopDeptsTable
	SELECT t1.Accession, Project, NumDepts, t2.OrgR
	FROM ( 
	SELECT	
		t1.Accession, 
		Project,
		COUNT(*) NumDepts
	FROM [dbo].udf_AD419ProjectsForFiscalYear(@FiscalYear) t1
	LEFT OUTER JOIN InterdepartmentalProjectsImport t2 ON t1.Accession = RIGHT('0000000' + t2.AccessionNumber, 7)
	WHERE isInterdepartmental = 1 
	GROUP BY t1.Accession, Project) t1
	INNER JOIN dbo.InterdepartmentalProjectsImport t2 ON t1.Accession = RIGHT('0000000' + t2.AccessionNumber, 7) WHERE Year = @FiscalYear
	GROUP BY t1.Accession, T1.Project, T1.NumDepts, t2.OrgR
	ORDER BY t1.Accession, T1.Project, T1.NumDepts, t2.OrgR

	IF @DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 0
		DELETE FROM @CoopDeptsTable WHERE Accession IN (SELECT DISTINCT Accession FROM dbo.ProjXOrgR)

	SELECT 'Projects to be inserted for OrgR: ' Legend
	SELECT * FROM @CoopDeptsTable

	DECLARE @return_value int = 0
	DECLARE @OrgR varchar(4)
	DECLARE @Accession varchar(50), @Project varchar(50), @NumDepts int, @DeptNum int, @StartPosn int, @CoopDept varchar(4), @Name varchar(50)
	DECLARE MyCursor CURSOR FOR
		SELECT DISTINCT Accession, Project, NumDepts
		FROM @CoopDeptsTable
		GROUP BY Accession, Project, NumDepts
		ORDER BY Accession, Project, NumDepts

	OPEN myCursor
	FETCH NEXT FROM myCursor INTO @Accession, @Project, @NumDepts
	WHILE @@FETCH_STATUS <> -1
	BEGIN
		IF @IsDebug = 1
			PRINT  '--Accession: ' + @Accession + ', Project: '+  @Project+ ', NumDepts: '+  CONVERT(varchar(5), @NumDepts)
			
        SELECT @DeptNum = 0
		DECLARE OrgCursor CURSOR FOR 
			SELECT OrgR
			FROM @CoopDeptsTable
			WHERE Accession = @Accession
			ORDER BY OrgR
		OPEN OrgCursor
		FETCH NEXT FROM OrgCursor INTO @OrgR
		WHILE @@FETCH_STATUS <> -1
		BEGIN
			SELECT @DeptNum = @DeptNum + 1

			IF @IsDebug = 1
				PRINT '--Coop Dept(' + CONVERT(varchar(5), @DeptNum) + '): ' +  @OrgR + '
	'
			SELECT @Name = (SELECT OrgShortName FROM dbo.ReportingOrg WHERE OrgR = @OrgR ) 

			IF @IsDebug = 1
				PRINT '--' + CONVERT(varchar(5), @DeptNum) + ': ' + @Project +', ' + @Accession + ': OrgR: ' + @OrgR + '; ' + @Name + '
	'
			SELECT @TSQL = '	EXEC [dbo].[usp_insertSecondaryDepartments] @Accession = ' + QUOTENAME(@Accession,'''') + ', @OrgR = ' + QUOTENAME(@OrgR,'''') + ''
			IF @IsDebug = 1
				PRINT @TSQL
			ELSE
			BEGIN
				PRINT @TSQL
				EXEC @return_value = sp_executesql @TSQL
				PRINT	'Return Value = ' + CONVERT(varchar(5), @return_value)
			END

			FETCH NEXT FROM OrgCursor INTO @OrgR
		END 
		CLOSE OrgCursor
		DEALLOCATE OrgCursor
		FETCH NEXT FROM myCursor INTO @Accession, @Project, @NumDepts

		PRINT '
	'
	END
	CLOSE myCursor
	DEALLOCATE myCursor

	-- sanity check to make sure all interdepartmental orgs have their orgs identified.
	SELECT 'There should be zero rows below; otherwise, not all projects have departments assigned:' AS Message
	SELECT accession from udf_AD419ProjectsForFiscalYear(@FiscalYear) where isInterdepartmental = 1
	EXCEPT
	SELECT DISTINCT Accession FROM ProjXOrgR WHERE Accession IN (
	SELECT DISTINCT Accession 
		FROM [dbo].udf_AD419ProjectsForFiscalYear(@FiscalYear)
		WHERE IsInterdepartmental = 1
	)
END