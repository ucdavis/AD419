
-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-01-06
-- Description:	Load the TransLog table 
-- using all records returned from TransactionLogV
-- meeting the date criteria determined from the input parameters.
--
-- Notes: Run this script after updating the FISDataMart,
-- since it relies on many of the tables and indexes.

-- NOTE ALSO: This script does not have any merge capability, so the table must
-- have either been truncated manually or by the calling sproc.
--
-- Modifications:
--	2011-03-04 by kjt:
--		Added logic to pass a destination table name; otherwise defaults to TransLog.
--	2011-06-15 by kjt:
--		Added logic to populate new FringeBenefit fields required by Steve Pesis.
-- 
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadNamedTransLogTable] 
	@FirstDateString varchar(16) = null,
		--earliest date to download  
		--optional, defaults to highest date in table
	@LastDateString varchar(16) = null,
		-- latest date to download 
		-- optional, defaults to today's date.
	@GetUpdatesOnly bit = 1, -- This parameter is just a placeholder so that it can be called
		-- using usp_Download_TableRecordsForFiscalYear.
	@TableName varchar(255) = 'TransLog', --Can be passed another table name, i.e. #TransLog, etc.
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute it. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	-- SET NOCOUNT ON;
	
	-- Minimal date logic used to build the where clause,
	-- because the assumption is that is was derermined by the 
	-- calling procedure.
	
	DECLARE @FirstDate datetime = null
	DECLARE @LastDate datetime = null
	DECLARE @BeginningFiscalYear int = null
	DECLARE @EndingFiscalYear int = null
	
	DECLARE @TSQL varchar(MAX) = ''
	DECLARE @WhereClause varchar(MAX) = ''
	
	DECLARE @NumFiscalYearsToDownload smallint = 1
	DECLARE @RecordCount int = 0
	--DECLARE @TableName varchar(255) = 'TransLog' --Name of table being updated.
	DECLARE @TruncateTable bit = 0 --Whether or not to truncate the table before load.  This is not set from this sproc, 
	-- but left for consistency.
	DECLARE @Exclude9999FiscalYear bit = 0 
-------------------------------------------------------------------------------------
	DECLARE MyCursor CURSOR FOR SELECT BeginningFiscalYear, EndingFiscalYear, NumFiscalYearsToDownload, FirstDate, LastDate, RecordCount 
	FROM udf_GetBeginningAndLastFiscalYearToDownload(@TableName, @FirstDateString, @LastDateString, @NumFiscalYearsToDownload, @TruncateTable, @Exclude9999FiscalYear)
	
	OPEN MyCursor
	
	FETCH NEXT FROM MyCursor INTO @BeginningFiscalYear, @EndingFiscalYear, @NumFiscalYearsToDownload, @FirstDate, @LastDate, @RecordCount
	
	CLOSE MyCursor
	DEALLOCATE MyCursor
	
	IF @IsDebug = 1 PRINT '--@NumFiscalYearsToDownload: ' + Convert(varchar(20), @NumFiscalYearsToDownload) 
-------------------------------------------------------------------------------------	
	/*
		IF @IsDebug = 1 
		BEGIN
			PRINT '--Before setting first and last date:
			'
			PRINT '--@FirstDateString: ' + ISNULL(Convert(varchar(20), @FirstDateString), 'NULL')
			PRINT '--@LastDateString: ' + ISNULL(Convert(varchar(20), @LastDateString), 'NULL')
		END
		
	Select @FirstDate = convert(smalldatetime,@FirstDateString)
	Select @LastDate = convert(smalldatetime,@LastDateString)
	
		IF @IsDebug = 1 
		BEGIN
			PRINT '--After setting first and last date:	
			'	
			PRINT '--@FirstDate: ' + ISNULL(Convert(varchar(20), @FirstDate), 'NULL')
			PRINT '--@LastDate: ' + ISNULL(Convert(varchar(20), @LastDate), 'NULL')
		END

	Select @BeginningFiscalYear = (
				CASE WHEN (MONTH(@FirstDate) >=1 AND MONTH(@FirstDate) < 6) OR (MONTH(@FirstDate) = 6 AND DAY(@FirstDate) <=30) THEN YEAR(@FirstDate)
				ELSE YEAR(@FirstDate) +1 
				END)
				
	Select @EndingFiscalYear = (
			CASE WHEN (MONTH(@LastDate) >=1 AND MONTH(@LastDate) < 6) OR (MONTH(@LastDate) = 6 AND DAY(@LastDate) <=30) THEN YEAR(@LastDate)
			ELSE YEAR(@LastDate) +1 
			END)
	PRINT '--Ending Fiscal Year: ' + ISNULL(CONVERT(varchar(4), @EndingFiscalYear), 'NULL')
	
	IF @IsDebug = 1 
		BEGIN
			PRINT '--After setting beginning and ending fiscal year:
			'
			PRINT '--@BeginningFiscalYear: ' + ISNULL(Convert(varchar(4), @BeginningFiscalYear), 'NULL')
			PRINT '--@EndingFiscalYear: ' + ISNULL(Convert(varchar(4), @EndingFiscalYear), 'NULL')
		END
	*/
	SELECT @WhereClause = 
'FiscalYear' +
CASE WHEN @BeginningFiscalYear <> @EndingFiscalYear AND
          (@EndingFiscalYear <> 9999 AND @EndingFiscalYear <> 1900) THEN
' BETWEEN ' + Convert(char(4), @BeginningFiscalYear) +
		 ' AND ' + + Convert(char(4), @EndingFiscalYear)
WHEN (@EndingFiscalYear = 9999 OR @EndingFiscalYear = 1900) THEN
' >= ' + Convert(char(4), @BeginningFiscalYear)
ELSE 
' = ' + Convert(char(4), @BeginningFiscalYear)
END 
	
-- Insert TransactionLogV records into TransLog:

	select @TSQL = 
	'
INSERT INTO ' + @TableName + '
	(
	   [PKTrans]
      ,[OrganizationFK]
      ,[FiscalYear]
      ,[FiscalPeriod]
      ,[Chart]
      ,[OrgCode]
      ,[OrgName]
      ,[OrgLevel]
      ,[OrgType]
      ,[Level1_OrgCode]
      ,[Level1_OrgName]
      ,[Level2_OrgCode]
      ,[Level2_OrgName]
      ,[Level3_OrgCode]
      ,[Level3_OrgName]
      ,[Account]
      ,[AccountNum]
      ,[AccountName]
      ,[AccountManager]
      ,[PrincipalInvestigator]
      ,[AccountType]
      ,[AccountPurpose]
      ,[FederalAgencyCode]
      ,[AccountAwardNumber]
      ,[AccountAwardType]
      ,[AccountAwardAmount]
      ,[AccountAwardEndDate]
      ,[HigherEdFunctionCode]
      ,[FringeBenefitIndicator]
	  ,[FringeBenefitChart]
	  ,[FringeBenefitAccount]
      ,[AccountFunctionCode]
      ,[OPAccount]
      ,[OPFund]
      ,[OPFundName]
      ,[OPFundGroup]
      ,[OPFundGroupName]
      ,[AccountFundGroup]
      ,[AccountFundGroupName]
      ,[SubFundGroup]
      ,[SubFundGroupName]
      ,[SubFundGroupType]
      ,[SubFundGroupTypeName]
      ,[AnnualReportCode]
      ,[SubAccount]
      ,[SubAccountName]
      ,[ObjectCode]
      ,[ObjectName]
      ,[ObjectShortName]
      ,[BudgetAggregationCode]
      ,[ObjectType]
      ,[ObjectTypeName]
      ,[ObjectLevelName]
      ,[ObjectLevelShortName]
      ,[ObjectLevelCode]
      ,[ObjectSubType]
      ,[ObjectSubTypeName]
      ,[ConsolidationCode]
      ,[ConsolidationName]
      ,[ConsolidationShortName]
      ,[SubObject]
      ,[ProjectCode]
      ,[ProjectName]
      ,[ProjectManager]
      ,[ProjectDescription]
      ,[TransDocType]
      ,[TransDocTypeName]
      ,[TransDocOrigin]
      ,[DocumentNumber]
      ,[TransDocNum]
      ,[TransDocTrackNum]
      ,[TransDocInitiator]
      ,[TransInitDate]
      ,[LineSequenceNum]
      ,[TransDescription]
      ,[TransLineAmount]
      ,[TransBalanceType]
      ,[ExpendAmount]
      ,[AppropAmount]
      ,[EncumbAmount]
      ,[TransLineReference]
      ,[TransPriorDocTypeNum]
      ,[TransPriorDocOrigin]
      ,[TransPriorDocNum]
      ,[TransEncumUpdateCode]
      ,[TransCreationDate]
      ,[TransPostDate]
      ,[TransReversalDate]
      ,[TransChangeDate]
      ,[TransSourceTableCode]
      ,[IsPendingTrans]
      ,[IsCAESTrans]
      )
      
  SELECT 
	   [PKTrans]
      ,[OrganizationFK]
      ,[FiscalYear]
      ,[FiscalPeriod]
      ,[Chart]
      ,[OrgCode]
      ,[OrgName]
      ,[OrgLevel]
      ,[OrgType]
      ,[Level1_OrgCode]
      ,[Level1_OrgName]
      ,[Level2_OrgCode]
      ,[Level2_OrgName]
      ,[Level3_OrgCode]
      ,[Level3_OrgName]
      ,[Account]
      ,[AccountNum]
      ,[AccountName]
      ,[AccountManager]
      ,[PrincipalInvestigator]
      ,[AccountType]
      ,[AccountPurpose]
      ,[FederalAgencyCode]
      ,[AccountAwardNumber]
      ,[AccountAwardType]
      ,[AccountAwardAmount]
      ,[AccountAwardEndDate]
      ,[HigherEdFunctionCode]
      ,[FringeBenefitIndicator]
	  ,[FringeBenefitChart]
	  ,[FringeBenefitAccount]
      ,[AccountFunctionCode]
      ,[OPAccount]
      ,[OPFund]
      ,[OPFundName]
      ,[OPFundGroup]
      ,[OPFundGroupName]
      ,[AccountFundGroup]
      ,[AccountFundGroupName]
      ,[SubFundGroup]
      ,[SubFundGroupName]
      ,[SubFundGroupType]
      ,[SubFundGroupTypeName]
      ,[AnnualReportCode]
      ,[SubAccount]
      ,[SubAccountName]
      ,[ObjectCode]
      ,[ObjectName]
      ,[ObjectShortName]
      ,[BudgetAggregationCode]
      ,[ObjectType]
      ,[ObjectTypeName]
      ,[ObjectLevelName]
      ,[ObjectLevelShortName]
      ,[ObjectLevelCode]
      ,[ObjectSubType]
      ,[ObjectSubTypeName]
      ,[ConsolidationCode]
      ,[ConsolidationName]
      ,[ConsolidationShortName]
      ,[SubObject]
      ,[ProjectCode]
      ,[ProjectName]
      ,[ProjectManager]
      ,[ProjectDescription]
      ,[TransDocType]
      ,[TransDocTypeName]
      ,[TransDocOrigin]
      ,[DocumentNumber]
      ,[TransDocNum]
      ,[TransDocTrackNum]
      ,[TransDocInitiator]
      ,[TransInitDate]
      ,[LineSequenceNum]
      ,[TransDescription]
      ,[TransLineAmount]
      ,[TransBalanceType]
      ,[ExpendAmount]
      ,[AppropAmount]
      ,[EncumbAmount]
      ,[TransLineReference]
      ,[TransPriorDocTypeNum]
      ,[TransPriorDocOrigin]
      ,[TransPriorDocNum]
      ,[TransEncumUpdateCode]
      ,[TransCreationDate]
      ,[TransPostDate]
      ,[TransReversalDate]
      ,[TransChangeDate]
      ,[TransSourceTableCode]
      ,[IsPendingTrans]
      ,[IsCAESTrans]
  FROM [FISDataMart].[dbo].[TransactionLogV]
  WHERE 
		' + @WhereClause + '
'
		
-------------------------------------------------------------------------
	if @IsDebug = 1
		BEGIN
			--used for testing
			PRINT @TSQL	
		END
	else
		BEGIN
			--Execute the command:
			EXEC(@TSQL)
		END
END
