-- =============================================
-- Author:		<Ken Taylor>
-- Create date: <Sept. 21, 2009>
-- Description:	<Call ups_DownloadPendingTransactions for both AAES and BIOS>
-- Modifications:
--	2011-02-06 by kjt: Revised logic not to truncate table if @IsDebug = 1.
--	Added logic and params to disable and enable/rebuild indexes.
--  2011-02-14 by kjt:
--	Revised to use merge statements to test if increased performance.
--	Added @TruncateTable param.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Download_AAES_BIOS_PendingTransactions_wMerge]
	-- Add the parameters for the stored procedure here
	/*
	<@Param1, sysname, @p1> <Datatype_For_Param1, , int> = <Default_Value_For_Param1, , 0>, 
	<@Param2, sysname, @p2> <Datatype_For_Param2, , int> = <Default_Value_For_Param2, , 0>
	*/
	@FiscalYear int = null,
	@TruncateTable bit = 0, --Set to 1 to truncate table.
	@DisableIndexes bit = 1, --Set to 0 NOT to disable indexes.
	@RebuildIndexes bit = 0, --Set to 1 to rebuild indexes.
	@IsDebug bit = 0 --Set to 1 to NOT execute, but only print SQL.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
    DECLARE @TSQLOut varchar(MAX) = ''
    DECLARE @TableName varchar(255) = 'PendingTrans'
    DECLARE @TSQL varchar(MAX) = ''
    
    IF @TruncateTable = 1
		BEGIN
			SELECT @TSQL = '
	truncate table [FISDataMart].dbo.PendingTrans;
    '
			IF @IsDebug = 1
				PRINT @TSQL
			ELSE
				EXEC (@TSQL)
		END
		
	-- Disable indexes as specified:	
	IF @DisableIndexes = 1
		BEGIN
			SELECT @TSQL = '
	--EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''AAES'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
    EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '	
			'
			EXEC(@TSQL)
		END
    
	-- Pending Transactions for AAES
	SELECT @TSQL = '
	merge [FISDataMart].dbo.PendingTrans AS PendingTrans
	using
	(
	'
	IF @IsDebug = 1
		SELECT @TSQL += '--EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''AAES'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
		
	'
	
    EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = 'AAES', @FiscalYear = @FiscalYear, @IsDebug = @IsDebug, @TSQLOut = @TSQLOut OUTPUT
			SELECT @TSQL += @TSQLOut 

		
	SELECT @TSQL += '
	
		UNION ALL
		
	'
	IF @IsDebug = 1
		SELECT @TSQL += '--EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''BIOS'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
		
	'
	 SELECT @TSQLOut = ''
	 EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = 'BIOS', @FiscalYear = @FiscalYear, @IsDebug = @IsDebug, @TSQLOut = @TSQLOut OUTPUT
			SELECT @TSQL += @TSQLOut
	
    SELECT @TSQL += '
     ) FIS_DS_PENDING_TRANS ON PendingTrans.PKPendingTrans = FIS_DS_PENDING_TRANS.PKPendingTrans
     
     WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
     (
       [PKPendingTrans]
      ,[Year]
      ,[Period]
      ,[Chart]
      ,[OrgID]
      ,[AccountType]
      ,[Account]
      ,[SubAccount]
      ,[ObjectTypeCode]
      ,[Object]
      ,[SubObject]
      ,[BalType]
      ,[DocType]
      ,[DocOrigin]
      ,[DocNum]
      ,[DocTrackNum]
      ,[InitrID]
      ,[InitDate]
      ,[LineSquenceNumber]
      ,[LineDesc]
      ,[LineAmount]
      ,[Project]
      ,[OrgRefNum]
      ,[PriorDocTypeNum]
      ,[PriorDocOriginCd]
      ,[PriorDocNum]
      ,[EncumUpdtCd]
      ,[PostDate]
      ,[ReversalDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK]
      ,[IsCAES]
      )
      
      WHEN NOT MATCHED BY SOURCE THEN DELETE
;'

      IF @IsDebug = 1
		PRINT @TSQL
      ELSE
		BEGIN
			PRINT @TSQL
			EXEC(@TSQL)
		END
	  
	  -- Rebuild indexes as specified:
	  IF @RebuildIndexes = 1
		BEGIN
			SELECT @TSQL = '
    EXEC usp_RebuildAllTableIndexes @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '			
			'
			EXEC(@TSQL)
		END
END