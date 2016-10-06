-- =============================================
-- Author:		Ken Taylor
-- Create date: 01/03/2011
-- Description:	This usp runs all of the FIS Datamart usp_Download... scripts.
-- Make sure that the three (3) reference tables have been loaded first.  (This is
-- usually done as part of the create script).
-- Modifications: 
-- 20110217 by kjt:
--	Replaced call to download Pending Trans with usp_DownloadPendingTransactions.
-- 20110224 ky kjt:
--	Replaced call to Download Trans with usp_DownloadTransactionsForFiscalYear.
-- 20110305 by kjt:
--	Added RebuildIndexes to cursor and table.
--	Added Timing print outs.
-- 20110331 by kjt:
--	Changed GeneralLedgerPeriodBalances references for GeneralLedgerProjectBalancesForAllPeriods.
--	Revised order of tables; put PendingTrans before trans.
-- 20110411 by kjt:
--	Revised to not disable or rebuild indexes for larger tables as SQL Server
-- update index algorithm appears to be faster doing them in place.
-- 20110419 by kjt:
--	Added additional param @TruncateTables, so that this sproc could also be used for updates
--  as well as empty, initial database loads.
-- 20110425 by kjt:
--	Changed call to usp_DownloadGeneralLedgerProjectBalancesForAllPeriods to pass @TruncateTables param.
-- 20160623 by kjt: 
--	Removed call to usp_DownloadProjects as there is an issue with corrupted data in the table that causes the whole sproc to fail. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_DownloadFISDataMart] 
	-- Add the parameters for the stored procedure here
	@TruncateTables bit = 1, -- Set this to 1 to do a full database reload, not just an update.
	@IsDebug bit = 0, -- Set to 1 to just display SQL.
	@IsVerboseDebug bit = 0  -- Set to 1 to show inner, i.e., called SQL also. 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @true bit = 1, @false bit = 0 --variables to hold the true/false bit equiv.
	
	-- Table to hold all the table names to load and the sprocs that load the data for the corresponding table.
	DECLARE @TablesNamesAndDownloadSprocNames TABLE (TableName varchar(255), DownloadSprocName varchar(255), UseGenericSproc bit, TruncateTable bit, DisableIndexes bit, RebuildIndexes bit)
	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('AccountType', 'usp_DownloadAccountTypes', @false, @true, @true, @true )
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('BalanceTypes', 'usp_DownloadBalanceTypes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('BillingIDConversions', 'usp_DownloadBillingIDConversions', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('DocumentOriginCodes', 'usp_DownloadDocumentOriginCodes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('DocumentTypes', 'usp_DownloadDocumentTypes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('FundGroups', 'usp_DownloadFundGroups', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('HigherEducationFunctionCodes', 'usp_DownloadHigherEducationFunctionCodes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('ObjectSubTypes', 'usp_DownloadObjectSubTypes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('ObjectTypes', 'usp_DownloadObjectTypes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubFundGroupTypes', 'usp_DownloadSubFundGroupTypes', @false, @true, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Accounts', 'usp_DownloadAccounts', @true, @TruncateTables, @false, @false)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('GeneralLedgerProjectBalanceForAllPeriods', 'usp_DownloadGeneralLedgerProjectBalancesForAllPeriods', @true, @TruncateTables, @false, @false)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Objects', 'usp_DownloadObjects', @true, @TruncateTables, @false, @false)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('OPFund', 'usp_DownloadOPFund', @true, @TruncateTables, @false, @false)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Organizations', 'usp_DownloadOrganizations', @true, @false, @false, @false)
	--INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Projects', 'usp_DownloadProjects', @true, @TruncateTables, @false, @false)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubAccounts', 'usp_DownloadSubAccount', @true, @TruncateTables, @false, @false)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubFundGroups', 'usp_DownloadSubFundGroups', @true, @TruncateTables, @false, @false)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubObjects', 'usp_DownloadSubObjects', @true, @TruncateTables, @false, @false)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('PendingTrans', 'usp_DownloadPendingTransactions', @false, @true, @false, @false)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Trans', 'usp_DownloadTransactionsForFiscalYear', @true, @TruncateTables, @false, @false)	
	
	DECLARE @TableName varchar(255), @DownloadSprocName varchar(255), @UseGenericSproc bit, @TruncateTable bit, @DisableIndexes bit, @RebuildIndexes bit
		
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
    PRINT '--DownloadFISDataMart started at: ' + CONVERT(varchar(20),@StartTime, 114)
    
    IF @IsVerboseDebug = 1 SELECT @IsDebug = 1
    
	DECLARE @TSQL varchar(MAX) = '--Executing usp_DownloadFISDataMart...
	'
		
	DECLARE TCursor CURSOR FOR SELECT * FROM @TablesNamesAndDownloadSprocNames
	
	OPEN TCursor
	FETCH NEXT FROM TCursor INTO @TableName, @DownloadSprocName, @UseGenericSproc, @TruncateTable, @DisableIndexes, @RebuildIndexes
	
	WHILE (@@FETCH_STATUS <> -1)	
		BEGIN
			IF @IsVerboseDebug = 1
				BEGIN
					IF @UseGenericSproc = @true
						BEGIN
							PRINT '--Calling EXEC usp_Download_TableRecordsForFiscalYear @TableName = ''' + @TableName + ''', @DownloadSprocName = ''' + @DownloadSprocName + ''', @TruncateTable = ' + CONVERT(char(1), @TruncateTable) + ', @DisableIndexes = ' + CONVERT(char(1), @DisableIndexes) + ', @RebuildIndexes = ' + CONVERT(char(1), @RebuildIndexes) + ', @IsDebug = ' + CONVERT(char(1), @IsDebug)
							EXEC [dbo].[usp_Download_TableRecordsForFiscalYear] @TableName = @TableName, @DownloadSprocName = @DownloadSprocName, @TruncateTable = @TruncateTable, @DisableIndexes = @DisableIndexes, @IsDebug = @IsDebug
						END
					ELSE
						BEGIN
							PRINT '--Calling EXEC ' + @DownloadSprocName + ' @IsDebug = ' + CONVERT(char(1), @IsDebug)
							EXEC('EXEC ' + @DownloadSprocName + ' @IsDebug = ' + @IsDebug)
						END
				END
			ELSE
				BEGIN
				IF @UseGenericSproc = @true
					BEGIN
						SELECT @TSQL += 'EXEC [dbo].[usp_Download_TableRecordsForFiscalYear] @TableName = ''' + @TableName + ''', @DownloadSprocName = ''' + @DownloadSprocName + ''', @TruncateTable = ' + CONVERT(char(1), @TruncateTable) + ', @DisableIndexes = ' + CONVERT(char(1), @DisableIndexes) + ', @RebuildIndexes = ' + CONVERT(char(1), @RebuildIndexes) + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	'
					END
				ELSE
					BEGIN
						SELECT @TSQL += 'EXEC ' + @DownloadSprocName + ' @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
	'
					END
				END
		
			FETCH NEXT FROM TCursor INTO @TableName, @DownloadSprocName, @UseGenericSproc, @TruncateTable, @DisableIndexes, @RebuildIndexes
		END
	
	CLOSE TCursor
	DEALLOCATE TCursor

-------------------------------------------------------------------------
	IF @IsVerboseDebug = 0
		BEGIN
			IF @IsDebug = 1
				BEGIN
					--used for testing
					PRINT @TSQL	
				END
			ELSE
				BEGIN
					--Execute the command:
					EXEC(@TSQL)
					
					SELECT @StartTime = (@TempTime)
					SELECT @EndTime = (GETDATE())
					PRINT '--DownloadFISDataMart ended at: ' + CONVERT(varchar(20),@EndTime, 114)
					PRINT '--DownloadFISDataMart executed in: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)

				END	
		END
END
