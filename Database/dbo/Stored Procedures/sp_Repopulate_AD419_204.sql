-- =============================================
-- Author:		Ken Taylor
-- Create date: August 13, 2016
-- Description:	This gets the pre-associated expenses from [dbo].[204AcctXProjV]
-- and inserts them into AcctX204Proj table.
--
-- Notes:  Make sure you run this after all of the 204 account tables have been populated
-- programatically, but prior to anyone addding a 204 expenses via the AD-419 application
-- admin portal; otherwise, the user added data will be deleted!
--
-- Usage:
/*
	USE AD419
	GO

	DECLARE @ReturnVal int = 0
	EXEC @ReturnVal = [dbo].[sp_Repopulate_AD419_204] @FiscalYear = 2015, @IsDebug = 0
	PRINT '  -- ReturnVal: '+CONVERT(varchar(5), @ReturnVal)

	GO
*/
-- Modifications:
--  2016-08-13 by kjt: Revised to used the new 204AcctXProjV view, which already has the project associations.
--	2016-09-09 by kjt: Fixed OrgR, Org column swap.
--	20160912 by kjt: Added OpFundNum.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Repopulate_AD419_204] (
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2015,
	@IsDebug bit = 0
)
AS
BEGIN
	DECLARE @TSQL varchar(max) = ''
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	-- Delete all the records from the 204AcctXProj table:
	Select @TSQL = '	TRUNCATE TABLE [204AcctXProj];'
	
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
	----------------------------------------------------------------------------------------------------------
	
	Select @TSQL = '
	INSERT INTO [204AcctXProj] 
	(
	   [AccountID]
      ,[Expenses]
      ,[DividedAmount]
      ,[FTE]
      ,[Accession]
      ,[ProjectNumber]
      ,[Chart]
      ,[Is219]
      ,[CSREES_ContractNo]
      ,[AwardNum]
	  ,[OpFundNum]
      ,[ProjectEndDate]
      ,[IsCurrentProject]
      ,[Org]
	  ,[OrgR]
      ,[IsExcludedExpense]
	)
	SELECT 
	   [AccountID]
      ,[Expenses]
      ,[DividedAmount]
      ,[FTE]
      ,[Accession]
      ,[ProjectNumber]
      ,[Chart]
      ,[Is219]
      ,[CSREES_ContractNo]
      ,[AwardNum]
	  ,[OpFundNum]
      ,[ProjectEndDate]
      ,[IsCurrentProject]
      ,[Org]
	  ,[OrgR]
      ,[IsExcludedExpense]
  FROM [AD419].[dbo].[204AcctXProjV]    
'
		
	IF @IsDebug = 1
		BEGIN
			SET NOCOUNT ON
			Print @TSQL
			SET NOCOUNT OFF
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END

END