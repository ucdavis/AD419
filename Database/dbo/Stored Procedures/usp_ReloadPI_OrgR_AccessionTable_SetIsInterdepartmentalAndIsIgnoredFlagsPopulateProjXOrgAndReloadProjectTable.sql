





-- =============================================
-- Author:		Ken Taylor
-- Create date: August 17, 2017
-- Description:	Repopulate PI_OrgR_Accession table, set the interdepartmental flag for projects
-- with Principal Investigators whom have AES appointments in multiple CA&ES departments.  
-- It also handles repopulating the ProjXOrgR table based on the PIs’ projects and their 
-- corresponding organizations as identified previously.  It also hides any 204 projects
-- whose expenses are less than $100, and lastly reloads the project table used by the AD-419
-- application.
--
-- Prerequisites:
--
--	The AllProjectsNew table must have been loaded.
--	The ProjectPI table must have been loaded.
--
-- Usage:
/*

	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_ReloadPI_OrgR_AccessionTable_SetIsInterdepartmentalAndIsIgnoredFlagsPopulateProjXOrgAndReloadProjectTable]

			@FiscalYear = 2016,
			@IsDebug = 1

	--SELECT	'Return Value' = @return_value

	GO

*/
-- Modifications:
--	20171005 by kjt: Changed isIgnored amount from <=100 to <100 as per AD-419 reporting instructions.
--	20180306 by kjt: Added check to test that all ProjectPI employeeIDs have been populated.
--		Changed name from usp_SetIsInterdepartmentalAndIsIgnoredFlagsPopulateProjXOrgAndReloadProjectTable to
--		usp_ReloadPI_OrgR_AccessionTable_SetIsInterdepartmentalAndIsIgnoredFlagsPopulateProjXOrgAndReloadProjectTable
--		Added call to Repopulate PI_OrgR_Accession table: usp_RepopulatePI_OrgR_Accession.
--	20181102 by kjt: Added INNER JOIN TO NifaProjectAccessionNumberImport table when loading project table
--		so that only current projects will be loaded. 
--	20181112 by kjt: Fixed ProjectPIsWithMissingEmployeeID check to use ProjectPI table instead of PI_OrgR_Accession, as
--		this sproc populates the PI_OrgR_Accession table, plus revised prerequisites to inducate as such.  Also added check
--		to make sure ProjectPI table was populated.
-- 20181210 by kjt: Revised logic for setting IsIgnored flag to also handle projects with no expenses accounts.
-- 20191114 by kjt: Revised logic so that 204 projects with no accounts, zero expenses or expenses <= $100 were ignored
--		prior to repopulating the PI_OrgR_Accession table, so that 241 expenses would not be assigned later to ignored
--		204 projects.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_ReloadPI_OrgR_AccessionTable_SetIsInterdepartmentalAndIsIgnoredFlagsPopulateProjXOrgAndReloadProjectTable] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE	@return_value int = -1 -- Default to error mode.

	DECLARE @ProjectPIsWithMissingEmployeeIDs int = 0, @AllProjectsCount int = 0, @ProjectPICount int = 0

	-- Verify that ProjectPI table has been loaded:
	SELECT @ProjectPICount = (
		SELECT Count(*)
		FROM [dbo].[ProjectPI]
	)

	-- Check to see that all the projectPIs have employeeIDs:
	SELECT @ProjectPIsWithMissingEmployeeIDs = (
		SELECT COUNT(*) 
		FROM [dbo].[ProjectPI]
		WHERE EmployeeID IS NULL OR EmployeeID LIKE ''
	)

	-- Check to see if the AllProjectsNew table has bee loaded:
	SELECT @AllProjectsCount = (
		SELECT Count(*)
		FROM [dbo].[AllProjectsNew]
	)

	DECLARE @ErrorMessage varchar(1024) = ''
	
	IF @ProjectPICount = 0
		SELECT @ErrorMessage = 'ProjectPI table has yet to be loaded.  Please run step which Identifies Account and Project PI.'
	ELSE IF @ProjectPIsWithMissingEmployeeIDs > 0
		SELECT @ErrorMessage = 'All Project PIs must have employee IDs.  Please find missing employee IDs and update.'
	ELSE IF @AllProjectsCount = 0
		SELECT @ErrorMessage = 'Projects must be imported before continuing.'
	
	IF @ErrorMessage IS NOT NULL AND @ErrorMessage NOT LIKE ''
	BEGIN
		IF @IsDebug = 1
			PRINT '-- ' + @ErrorMessage + '
	'
		IF @IsDebug = 0
		BEGIN
			RAISERROR(@ErrorMessage, 16, 1)
			RETURN -1
		END
	END

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
	SET NOCOUNT ON
	DECLARE	@return_value int

	-- 20191114 by kjt: Relocated this section to top of procedure so that ignored 204 projects would not
	-- be included later when auto-assigning 241 expenses.
	-------------------------------------------------------------------------------------------------------
	-- Project section:
	--
	-- The following project related procedures could either be done here or in a separate stored procedure:
	-- Prior to populating the project table from the ProjectV,
	-- We must temporarily set the AllProjectsNew "isIgnored" flag to true
	-- for any non-expired 204 project with a total expense amount less than
	-- or equal to $100.

	UPDATE AllProjectsNew
	SET IsIgnored = 1 
	WHERE AccessionNumber IN (
		SELECT AccessionNumber 
		FROM [dbo].[204ProjectsToBeExcludedFromDepartmentAssociationV]
	)

	-- Load Project using udf_AD419ProjectsForFiscalYear from AllProjectsNew:
	TRUNCATE TABLE [dbo].[Project]
	INSERT INTO [dbo].[Project]
	SELECT t1.* FROM [dbo].udf_AD419ProjectsForFiscalYear(' + CONVERT(varchar(4), @FiscalYear) + ') t1
	INNER JOIN [dbo].[NifaProjectAccessionNumberImport] t2 ON t1.Accession = t2.AccessionNumber

	-- End Project section.
	-------------------------------------------------------------------------------------------------------

	-- Repopulate PI_OrgR_Accession table:
	EXEC	@return_value = [dbo].[usp_RepopulatePI_OrgR_Accession]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '

--	SELECT	''Return Value'' = @return_value

	-- Repopulate the ProjXOrgR table using data from the PI_OrgR_Accession populated in a prior procedure:
	EXEC	@return_value = [dbo].[usp_RepopulateProjXOrgR_v2]
		@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
		@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '

--	SELECT	''Return Value'' = @return_value

	-- Set AllProjectsNew''s IsInterdepartmental Flag using data from the PI_OrgR_Accession populated in a prior procedure:
	EXEC [dbo].[usp_SetIsInterdepartmentalFlag] 
		@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
		@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '
'

	IF @IsDebug = 1
	BEGIN
		PRINT @TSQL
	END
	ELSE
	BEGIN
		EXEC(@TSQL)
	END
END