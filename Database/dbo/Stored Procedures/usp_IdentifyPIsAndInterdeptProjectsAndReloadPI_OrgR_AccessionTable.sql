
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 17, 2017
-- Description:	Determine which Employees are listed as Account principal 
-- investigators (PI) and/or Project PIs.  We then use this information to 
-- determine which PIs have multi-department Agricultural Experiment Station (AES)
-- appointments, and subsequently load the PI_OrgR_Accession table.
-- Once the PI_OrgR_Accession table has been loaded we have all the information
-- necessary to accurately set Project’s “IsInterdepartmental” flag, and load
-- the ProjXOrgR table in a subsequent step.
--
-- Prerequisites:
--
--	The NewAccountSFN table must have been loaded.
--	The AccountPI table must have been loaded.
--	The OrgXOrgR table must have been loaded.
--	The UCDPerson table must have updated.
--	The AllProjectsNew table must have been loaded.
--	The ProjectPI table must have been loaded.
--	The DOSCodes table must have been reviewed.
--	The ARCCodes table must have been reviewed.
--
-- Usage:
/*

	USE [AD419]
	GO

	DECLARE	@return_value int

	EXEC	@return_value = [dbo].[usp_IdentifyPIsAndInterdeptProjectsAndReloadPI_OrgR_AccessionTable]
			@FiscalYear = 2021,
			@IsDebug = 0

	--SELECT	'Return Value' = @return_value

	GO
*/
-- Modifications:
--	20211111 by kjt: Revised to use usp_RepopulateProjectPI_v3.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_IdentifyPIsAndInterdeptProjectsAndReloadPI_OrgR_AccessionTable] 
	@FiscalYear int = 2021, 
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

	-- Check to see that ProjectPI has been loaded:
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

	-- Repopulate PI_OrgR_Accession table:

	EXEC	@return_value = [dbo].[usp_RepopulatePI_OrgR_Accession]
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