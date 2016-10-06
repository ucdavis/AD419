-- =============================================
-- Author:		<Ken Taylor>
-- Create date: <Sept. 21, 2009>
-- Description:	<Call ups_DownloadTransactions for both AAES and BIOS>
-- =============================================
CREATE PROCEDURE [dbo].[usp_Download_AAES_BIOS_Transactions]
	-- Add the parameters for the stored procedure here
	/*
	<@Param1, sysname, @p1> <Datatype_For_Param1, , int> = <Default_Value_For_Param1, , 0>, 
	<@Param2, sysname, @p2> <Datatype_For_Param2, , int> = <Default_Value_For_Param2, , 0>
	*/
	@FirstDate varchar(16) = null,	--earliest date to download (GL_Applied.TRANS_GL_POSTED_DATE) 
		--optional, defaults to day after highest date in Trans table
	@LastDate varchar(16) = null,	--latest date to download 
		--optional, defaults to day after @FirstDate
	@CollegeOrg char(4) = null, -- either 'AAES' or 'BIOS'
	@IsDebug bit = 0 -- Set to 1 just print the SQL and not actually execute. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	-- Pending Transactions for AAES
	insert into [FISDataMart].dbo.Trans (
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
      ,[CreationDate]
      ,[PostDate]
      ,[ReversalDate]
      ,[ChangeDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK] 
      ,[IsCAES]
      , PKTrans
      )
      
      EXEC [dbo].[usp_DownloadTransactions] @CollegeOrg = 'AAES', @FirstDate = @FirstDate, @LastDate = @LastDate, @IsDebug = @IsDebug
      
      -- Pending Transactions for BIOS
      insert into [FISDataMart].dbo.Trans (
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
      ,[CreationDate]
      ,[PostDate]
      ,[ReversalDate]
      ,[ChangeDate]
      ,[SrcTblCd]
      ,[OrganizationFK]
      ,[AccountsFK]
      ,[ObjectsFK]
      ,[SubObjectFK]
      ,[SubAccountFK]
      ,[ProjectFK] 
      ,[IsCAES]
      , PKTrans
      )
      EXEC [dbo].[usp_DownloadTransactions] @CollegeOrg = 'BIOS', @FirstDate = @FirstDate, @LastDate = @LastDate, @IsDebug = @IsDebug
END