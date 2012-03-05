-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-02-03
-- Description:	Reload all the FISDataMart non-manually loaded tables.
-- Modifications:
--	20110305 by kjt:
--		Removed subsequent truncate log files, and added call to truncate all
--		non-manually loaded tables before reload.
--		Added call to EXEC usp_InsertMissingOrgsForDashDashPeriods.
--	20110411 by kjt:
--		Changed LoadTransLog portion to not disable indexes.
--	20110419 by kjt:
--		Added new param @TruncateTables so that sproc could also be used for update as
--		well as initially loading/reloading an empty database.
--	20110425 by kjt:
--		Modified to pass @TruncateTables param to underlying sprocs.
--	20110428 by kjt:
--		Added call to usp_InsertMissingAccountsForDashDashPeriods.
--		Revised ACBS Accounts portion to set Accounts.IsCAES = 2 where applicable.
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadFISDataMart]
	-- Add the parameters for the stored procedure here
	@TruncateTables bit = 1, --Set this to 1 to truncate all tables and 
							 --reload tables from scratch.
	@IsDebug bit = 0, --Set this to 1 to print SQL only.
	@IsVerboseDebug bit = 0 --Set this to 1 to recurse into the inner sprocs themselves.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
/*
	DECLARE @IsDebug bit = 0
*/	    
	IF @IsVerboseDebug = 1 SELECT @IsDebug = 1
	DECLARE @return_value int
	DECLARE @TSQL varchar(max) = ''
	SELECT @TSQL = '
	DECLARE @return_value int
	
	-- Truncate the log file:
	ALTER DATABASE FISDataMart SET RECOVERY SIMPLE
	ALTER DATABASE FISDataMart SET RECOVERY FULL
'
	IF @TruncateTables = 1
		SELECT @TSQL += '
	-- Truncate all the non-manually loaded tables before proceeding:
	EXEC usp_TruncateTablesForReload @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
'
	
	SELECT @TSQL += '
	-- Download the majority of the database except for the TransLog table, since it relies
	-- on a number of fully loaded and indexed tables:
	EXEC	@return_value = [dbo].[usp_DownloadFISDataMart] @TruncateTables = ' + CONVERT(char(1), @TruncateTables) + ',@IsDebug = ' + CONVERT(char(1), @IsDebug) + ', @IsVerboseDebug = ' + CONVERT(char(1), @IsVerboseDebug) + '
    SELECT	''Return Value'' = @return_value
    
    EXEC usp_InsertMissingAccountsForDashDashPeriods @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
    EXEC usp_InsertMissingOrgsForDashDashPeriods @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
    '
    IF @IsVerboseDebug = 1
		BEGIN
			PRINT '/*'
			PRINT @TSQL
			PRINT '*/'
			IF @TruncateTables = 1
				EXEC usp_TruncateTablesForReload @IsDebug = @IsDebug
			EXEC [dbo].[usp_DownloadFISDataMart] @TruncateTables = @TruncateTables, @IsDebug = @IsDebug , @IsVerboseDebug = @IsVerboseDebug
			EXEC usp_InsertMissingAccountsForDashDashPeriods @IsDebug = @IsDebug
			EXEC usp_InsertMissingOrgsForDashDashPeriods @IsDebug = @IsDebug
			SELECT @TSQL = ''
		END
	
	SELECT @TSQL += '
	-- Update the indexes next because the remaining items will run faster:

	EXEC	@return_value = [dbo].[usp_RebuildFISIndexes] @IsDebug = ' + CONVERT(char(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value
	'
	IF @IsVerboseDebug = 1
		BEGIN
			PRINT '/*'
			PRINT @TSQL
			PRINT '*/'
			EXEC [dbo].[usp_RebuildFISIndexes] @IsDebug = @IsDebug
			SELECT @TSQL = ''
		END
	
	SELECT @TSQL += '
	-- Set the Accounts.FunctionCodeID since these are not set at load time.

	EXEC	@return_value = [dbo].[usp_UpdateAccountsFunctionCodeID] @IsDebug = ' + CONVERT(char(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value
	'
	IF @IsVerboseDebug = 1
		BEGIN
			PRINT '/*'
			PRINT @TSQL
			PRINT '*/'
			EXEC [dbo].[usp_UpdateAccountsFunctionCodeID] @IsDebug = @IsDebug
			SELECT @TSQL = ''
		END
	
	SELECT @TSQL += '
	-- "Fix" all of the ACBS Org references that were formerly BIOS for the first part of FY 2010:
	-- Since this year has accounts with 2 orgs, the IsCAES field is getting set to 0 instead of 2
	-- as intended, so these will need to be reset to 2.
	
	update Accounts
	set IsCAES = ''2''
	WHERE Year = 2010
	AND Org IN (''ACBD'', ''AEVE'', ''AMCB'', ''AMIC'', ''ANPB'', ''APLB'')
	
	update Accounts
	set OrgFK = 
				''2010|--|'' + Chart + ''|'' + 
				(CASE Org 
		WHEN ''BDNO'' THEN ''ACBD''
		WHEN ''BEVO'' THEN ''AEVE''
		WHEN ''BMCO'' THEN ''AMCB''
		WHEN ''BMIO'' THEN ''AMIC''
		WHEN ''BNPO'' THEN ''ANPB''
		WHEN ''BPLO'' THEN ''APLB''
	END),
	IsCAES = 2
	Where Year = 2010
	AND Org in (''BDNO'', ''BEVO'', ''BMCO'', ''BMIO'', ''BNPO'', ''BPLO'')
	AND Account in (''BPLBOTH'',
	''MBOR039'',
	''BSRD11R'',
	''MIOR017'',
	''BSRESCH'',
	''EVOR094'',
	''BSFACOR'',
	''PBOR023'',
	''NPOR035'')
	
	update Trans
	set IsCAES = ''2''
	WHERE Year = 2010
	AND OrgID IN (''ACBD'', ''AEVE'', ''AMCB'', ''AMIC'', ''ANPB'', ''APLB'')

	update Trans
	set OrganizationFK = 
				''2010|--|'' + Chart + ''|'' + 
				(CASE OrgID 
		WHEN ''BDNO'' THEN ''ACBD''
		WHEN ''BEVO'' THEN ''AEVE''
		WHEN ''BMCO'' THEN ''AMCB''
		WHEN ''BMIO'' THEN ''AMIC''
		WHEN ''BNPO'' THEN ''ANPB''
		WHEN ''BPLO'' THEN ''APLB''
	END), IsCAES = 2
	Where Year = 2010
	AND OrgID in (''BDNO'', ''BEVO'', ''BMCO'', ''BMIO'', ''BNPO'', ''BPLO'')
	AND Account in (''BPLBOTH'',
	''MBOR039'',
	''BSRD11R'',
	''MIOR017'',
	''BSRESCH'',
	''EVOR094'',
	''BSFACOR'',
	''PBOR023'',
	''NPOR035'')
	
	update PendingTrans
	set IsCAES = ''2''
	WHERE Year = 2010
	AND OrgID IN (''ACBD'', ''AEVE'', ''AMCB'', ''AMIC'', ''ANPB'', ''APLB'')

	update PendingTrans
	set OrganizationFK = 
				''2010|--|'' + Chart + ''|'' + 
				(CASE OrgID 
		WHEN ''BDNO'' THEN ''ACBD''
		WHEN ''BEVO'' THEN ''AEVE''
		WHEN ''BMCO'' THEN ''AMCB''
		WHEN ''BMIO'' THEN ''AMIC''
		WHEN ''BNPO'' THEN ''ANPB''
		WHEN ''BPLO'' THEN ''APLB''
	END), IsCAES = 2
	Where Year = 2010
	AND OrgID in (''BDNO'', ''BEVO'', ''BMCO'', ''BMIO'', ''BNPO'', ''BPLO'')
	AND Account in (''BPLBOTH'',
	''MBOR039'',
	''BSRD11R'',
	''MIOR017'',
	''BSRESCH'',
	''EVOR094'',
	''BSFACOR'',
	''PBOR023'',
	''NPOR035'')
		
	-- Load the translog table last, since it relies on many of the other tables and indexes:
	/*
	Run this script last after updating the FISDataMart.
	*/

	EXEC	@return_value = [dbo].[usp_Download_TableRecordsForFiscalYear]
			@TableName = N''TransLog'',
			@DownloadSprocName = N''usp_LoadTransLog'',
			@TruncateTable = ' + CONVERT(char(1), @TruncateTables) + ',
			@DisableIndexes = 0,
			@RebuildIndexes = ' + CONVERT(char(1), @TruncateTables) + ',
			@IsDebug = ' + CONVERT(char(1), @IsDebug) + '

	SELECT	''Return Value'' = @return_value
	'
	IF @IsVerboseDebug = 1
		BEGIN
			PRINT '/*'
			PRINT @TSQL
			PRINT '*/'
			EXEC	@return_value = [dbo].[usp_Download_TableRecordsForFiscalYear]
			@TableName = N'TransLog',
			@DownloadSprocName = N'usp_LoadTransLog',
			@TruncateTable = @TruncateTables,
			@DisableIndexes = 0,
			@RebuildIndexes = @TruncateTables,
			@IsDebug = @IsDebug
			SELECT @TSQL = ''
		END
	
	SELECT @TSQL += '
	Print ''Done!''
'

	IF @IsDebug = 1
		BEGIN
			PRINT @TSQL
		END
	ELSE
		BEGIN
			DECLARE @StartTime datetime = (SELECT GETDATE())
			DECLARE @TempTime datetime = (SELECT @StartTime)
			DECLARE @EndTime datetime = (SELECT @StartTime)
			PRINT '--Load FISDataMart started at: ' + CONVERT(varchar(20),@StartTime, 114)

			EXEC(@TSQL)
			
			SELECT @StartTime = (@TempTime)
			SELECT @EndTime = (GETDATE())
			PRINT '--Load FISDataMart ended at: ' + CONVERT(varchar(20),@EndTime, 114)
			PRINT '--Total executiion time: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)
		END
END
