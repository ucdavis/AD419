-- =============================================
-- Author:		Ken Taylor
-- Create date: November 12, 2013
-- Description:	Replaces manual association of Interdepartmental projects 
-- to departments in ProgXOrgR using CoopDepts in AllProjects table.
--
-- NOTE: Make sure to update CoopDepts field prior to running!!!!!
--
-- Usage:
/*
-- For testing:
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects]
		@DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1,  --1 to emulate deleting existing records; 0 to show SQL that would actually be run in non-debug mode.
		@IsDebug = 1

SELECT	'Return Value' = @return_value

GO

-- For production:
USE [AD419]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects]
		@DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 1,
		@IsDebug = 0

SELECT	'Return Value' = @return_value

GO
*/
-- Modifications:
-- 2015-03-31 by kjt: Removed any [AD419] database specific references so that this sproc can be used with other databases
--		such as [AD419_2014], etc. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_RepopulateProjXOrgRForIntedepartmentalProjects] 
	-- Add the parameters for the stored procedure here
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
		FROM [AD419].[dbo].[Project]
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

	DECLARE @CoopDeptsTable TABLE (Accession varchar(50) ,Project varchar(50), CRIS_DeptID varchar(50), CoopDepts varchar(50), NumDepts int)

	INSERT INTO @CoopDeptsTable
	SELECT 
		Accession, 
		Project,
		CRIS_DeptID,
		CoopDepts, 
		CASE WHEN (LEN(CoopDepts) % 4 = 0) THEN LEN(CoopDepts)/4 ELSE 0 END NumDepts
	FROM dbo.AllProjects 
	WHERE IsCurrentAD419Project = 1 
		AND isInterdepartmental = 1 

	IF @DeleteExistingInterdepartmentalProjectsFromProjXOrgR = 0
		DELETE FROM @CoopDeptsTable WHERE Accession IN (SELECT DISTINCT Accession FROM dbo.ProjXOrgR)

	SELECT 'Projects to be inserted for OrgR: ' Legend
	SELECT * FROM @CoopDeptsTable

	DECLARE @return_value int = 0
	DECLARE @CoopDept varchar(4), @DeptNum int, @StartPosn int, @OrgR varchar(4), @Name varchar(100)
	DECLARE @Accession varchar(50), @Project varchar(50), @CRIS_DeptID varchar(50), @CoopDepts varchar(50), @NumDepts int
	DECLARE myCursor CURSOR FOR 
		SELECT Accession, Project, CRIS_DeptID, CoopDepts, NumDepts
		FROM @CoopDeptsTable
		ORDER BY Accession

	OPEN myCursor
	FETCH NEXT FROM myCursor INTO @Accession, @Project, @CRIS_DeptID, @CoopDepts, @NumDepts
	WHILE @@FETCH_STATUS <> -1
	BEGIN
		IF @IsDebug = 1
			PRINT  'Accession: ' + @Accession + ', Project: '+  @Project+ ', CRIS_DeptID: '+   @CRIS_DeptID+ ', CoopDepts: '+   @CoopDepts+ ', NumDepts: '+  CONVERT(varchar(5), @NumDepts)

		SELECT @DeptNum = 1
		SELECT @StartPosn = 1
		WHILE @DeptNum <= @NumDepts
		BEGIN
			SELECT @CoopDept = SUBSTRING(@CoopDepts, @StartPosn, 4)
			IF @IsDebug = 1
				PRINT 'Coop Dept(' + CONVERT(varchar(5), @DeptNum)+ '): ' +  @CoopDept + '
	'
			SELECT @OrgR = (SELECT OrgR FROM dbo.ReportingOrg WHERE CRISDeptCd = @CoopDept )
			SELECT @Name = (SELECT OrgShortName FROM dbo.ReportingOrg WHERE CRISDeptCd = @CoopDept ) 

			IF @IsDebug = 1
				PRINT @Project +', ' + @Accession + ': OrgR: ' + @OrgR + '; ' + @Name + '
	'
			SELECT @TSQL = '	EXEC [dbo].[usp_insertSecondaryDepartments] @Accession = ' + QUOTENAME(@Accession,'''') + ', @CRISDeptCd = ' + QUOTENAME(@CoopDept,'''') + ''
			IF @IsDebug = 1
				PRINT @TSQL
			ELSE
			BEGIN
				PRINT @TSQL
				EXEC @return_value = sp_executesql @TSQL
				PRINT	'Return Value = ' + CONVERT(varchar(5), @return_value)
			END

			SELECT @DeptNum = @DeptNum + 1
			SELECT @StartPosn = (1 + (@DeptNum - 1) * 4)
		END 
		FETCH NEXT FROM myCursor INTO @Accession, @Project, @CRIS_DeptID, @CoopDepts, @NumDepts

		PRINT '
	'
	END
	CLOSE myCursor
	DEALLOCATE myCursor
END