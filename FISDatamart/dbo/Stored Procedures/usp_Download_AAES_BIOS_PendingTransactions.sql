-- =============================================
-- Author:		<Ken Taylor>
-- Create date: <Sept. 21, 2009>
-- Description:	<Call ups_DownloadPendingTransactions for both AAES and BIOS>
-- Modifications:
--	2011-02-06 by kjt: Revised logic not to truncate table if @IsDebug = 1.
--	Added logic and params to disable and enable/rebuild indexes.
-- =============================================
CREATE PROCEDURE [dbo].[usp_Download_AAES_BIOS_PendingTransactions]
	-- Add the parameters for the stored procedure here
	/*
	<@Param1, sysname, @p1> <Datatype_For_Param1, , int> = <Default_Value_For_Param1, , 0>, 
	<@Param2, sysname, @p2> <Datatype_For_Param2, , int> = <Default_Value_For_Param2, , 0>
	*/
	@FiscalYear int = null,
	@DisableIndexes bit = 1, --Set to 0 NOT to disable indexes.
	@RebuildIndexes bit = 0, --Set to 1 to rebuild indexes.
	@IsDebug bit = 0 --Set to 1 to NOT execute, but only print SQL.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
    DECLARE @TableName varchar(255) = 'PendingTrans'
    DECLARE @TSQL varchar(MAX) = '
    truncate table [FISDataMart].dbo.PendingTrans;
    '
    IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
		
	-- Disable indexes as specified:	
	IF @DisableIndexes = 1
		BEGIN
			SELECT @TSQL = '
    EXEC usp_DisableAllTableIndexesExceptPkOrClustered @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '			
			'
			EXEC(@TSQL)
		END
    	
	-- Pending Transactions for AAES
	SELECT @TSQL = '
	insert into [FISDataMart].dbo.PendingTrans (
	   [Year]
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
      ,[ReversalDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK]
      ,[IsCAES]
      ,[PKPendingTrans]
     
      )
      
      --EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''AAES'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
      '
      IF @IsDebug = 1
		PRINT @TSQL
		
	  SELECT @TSQL += ' EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''AAES'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
      '
	  EXEC(@TSQL)
      
      
      -- Pending Transactions for BIOS
      SELECT @TSQL = '
      insert into [FISDataMart].dbo.PendingTrans (
	   [Year]
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
      ,[ReversalDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK]  
      ,[IsCAES]
      ,[PKPendingTrans]
      )
      
      --EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''BIOS'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
      '
 
      IF @IsDebug = 1
		PRINT @TSQL

      SELECT @TSQL += ' EXEC [dbo].[usp_DownloadPendingTransactions] @CollegeOrg = ''BIOS'', @FiscalYear = ' + ISNULL(CONVERT(varchar(4), @FiscalYear), 'NULL') + ', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '
      '
	  EXEC(@TSQL)
	  
	  -- Rebuild indexes as specified:
	  IF @RebuildIndexes = 1
		BEGIN
			SELECT @TSQL = '
    EXEC usp_RebuildAllTableIndexes @TableName = ' + @TableName +', @IsDebug = ' + CONVERT(char(1), @IsDebug) + '			
			'
			EXEC(@TSQL)
		END
END