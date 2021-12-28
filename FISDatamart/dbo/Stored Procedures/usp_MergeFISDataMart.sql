-- =============================================
-- Author:		Ken Taylor
-- Create date: 03/09/2011
-- Description:	This usp runs all of the FIS Datamart usp_Download... scripts for update purposes.
-- some of the table with a small number of rows, i.e. reference tables, will be truncated and reloaded.
-- Most tables with multiple years of data, especially Accounts and Transactions, will be merged.
-- Modifications: 
--	20110314 by kjt:
--		Changed "Download" to "Merge" as applicable.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_MergeFISDataMart] 
	-- Add the parameters for the stored procedure here
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
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Accounts', 'usp_DownloadAccounts', @true, @false, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('GeneralLedgerPeriodBalances', 'usp_DownloadGeneralLedgerPeriodBalances', @true, @false, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Objects', 'usp_DownloadObjects', @true, @false, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('OPFund', 'usp_DownloadOPFund', @true, @false, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Organizations', 'usp_DownloadOrganizations', @true, @false, @true, @true)
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('Projects', 'usp_DownloadProjects', @true, @false, @true, @true)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubAccounts', 'usp_DownloadSubAccount', @true, @false, @true, @true)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubFundGroups', 'usp_DownloadSubFundGroups', @true, @false, @true, @true)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('SubObjects', 'usp_DownloadSubObjects', @true, @false, @false, @true)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('PendingTrans', 'usp_DownloadPendingTransactions', @false, @true, @true, @true)	
	INSERT INTO @TablesNamesAndDownloadSprocNames VALUES ('TransLoad', 'usp_DownloadTransactionsForFiscalYear', @true, @false, @true, @true)	
	
	DECLARE @TableName varchar(255), @DownloadSprocName varchar(255), @UseGenericSproc bit, @TruncateTable bit, @DisableIndexes bit, @RebuildIndexes bit
		
	DECLARE @StartTime datetime = (SELECT GETDATE())
	DECLARE @TempTime datetime = (SELECT @StartTime)
	DECLARE @EndTime datetime = (SELECT @StartTime)
    PRINT '--MergeFISDataMart started at: ' + CONVERT(varchar(20),@StartTime, 114)
    
    IF @IsVerboseDebug = 1 SELECT @IsDebug = 1
    
	DECLARE @TSQL varchar(MAX) = '--Executing usp_MergeFISDataMart...
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
					PRINT '--MergeFISDataMart ended at: ' + CONVERT(varchar(20),@EndTime, 114)
					PRINT '--MergeFISDataMart executed in: ' + CONVERT(varchar(20),@EndTime - @StartTime, 114)

				END	
		END
END