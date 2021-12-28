


-- =============================================
-- Author:		Ken Taylor
-- Create date: March 6, 2018
-- Description:	Determine which Employees are listed as Account principal 
-- investigators (PI) and/or Project PIs.  We then use this information to 
-- determine which PIs have multi-department Agricultural Experiment Station (AES)
-- appointments.
-- 
-- This runs the sprocs that 
--	  Update the UCDPerson table,
--	  Update the AccountPI table, and 
--	  Update the ProjectPI table.
--
-- Prerequisites:
--
--	The NewAccountSFN table must have been loaded.
--	The OrgXOrgR table must have been loaded.
--	The AllProjectsNew table must have been loaded.
--	The DOSCodes table must have been reviewed.
--	The ARCCodes table must have been reviewed.
--
-- Usage:
/*

	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_IdentifyAccountAndProjectPIs]
			@FiscalYear = 2016,
			@IsDebug = 0

	--SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	2018-03-06 by kjt: Remove call to usp_RepopulatePI_OrgR_Accession, which populates PI_OrgR_Accession table, 
--	as this will happen after all employee IDs have been added for Project PIs with missing employee IDs, and
--	renamed from usp_IdentifyPIsAndInterdeptProjectsAndReloadPI_OrgR_AccessionTable to usp_IdentifyAccountAndProjectPIs.
--	2018-11-09 by kjt: Revised the pre-requsites as they were no longer accurate.  Also revised the comment regarding
--	check if the ProjectPI table was loaded to check if the AllOrgXOrgR table was loaded, since this sproc actually loads
--	the ProjectPI table.
--	2021-11-17 by kjt: Revised to use the new usp_RepopulateProjectPI_v3 sproc.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_IdentifyAccountAndProjectPIs] 
	@FiscalYear int = 2016, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE	@return_value int = -1 -- Default to error mode.
	
	DECLARE @NewAccountSFNCount int = 0, @OrgXOrgRCount int = 0, @AllProjectsCount int = 0

	-- Check to see if the AllProjectsNew table has bee loaded:
	SELECT @AllProjectsCount = (
		SELECT Count(*)
		FROM [dbo].[AllProjectsNew]
	)

	-- Check to see that NewAccountSFN has been loaded:
	SELECT @NewAccountSFNCount = (
		SELECT Count(*)
		FROM [dbo].[NewAccountSFN]
	)

	-- Check to see that AllOrgXOrgR has been loaded:
	SELECT @OrgXOrgRCount = (
		SELECT Count(*)
		FROM [dbo].[OrgXOrgR]
	)

	DECLARE @ErrorMessage varchar(1024) = ''
	
	IF @AllProjectsCount = 0
		SELECT @ErrorMessage = 'Projects must be imported before continuing.'
	ELSE IF @OrgXOrgRCount = 0
		SELECT @ErrorMessage = 'You must execute usp_PostPreImportReviewAutomation must be executed before continuing.'
	ELSE IF @NewAccountSFNCount = 0
		SELECT @ErrorMessage = 'You must execute usp_ClassifyAccounts_LoadTablesAndAttemptToMatch before continuing.'
	
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

	-- Merge the UCD_PERSON table:

	EXEC	@return_value = [dbo].[usp_MergeUCD_Person]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '

	SELECT	''Return Value'' = @return_value

	-- Merge the AccountPI table:

	EXEC	@return_value = [dbo].[usp_RepopulateAccountPI_v3]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '

	SELECT	''Return Value'' = @return_value

	-- Merge the ProjectPI table:

	EXEC	@return_value = [dbo].[usp_RepopulateProjectPI_v3]
			@FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ',
			@IsDebug = ' + CONVERT(varchar(5), @IsDebug) + '

	SELECT	''Return Value'' = @return_value

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