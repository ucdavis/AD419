-- =============================================
-- Author:		Ken Taylor
-- Create date: November 2, 2016
-- Description:	Truncate the AD-419 Expenses and Associations table, 
--	and reset the ProcessStatus and ProcessCategory IsCompleted flags 
-- to false back to category 13 so we can restart the process at step 13. 
--
-- Usage:
/*
	EXEC usp_DeleteAllExpensesAndAssocoationsAndResetStatus @IsDebug = 1 --*

-- *Note the the 2 parameters are just place holders and need not be provided.
*/
-- Modifications:
--	2017-09-21 by kjt: Revised to use updated process category sequence order from 13 to 15
--		because of the new steps that were added.
--	2018-11-09 by kjt: Revised to use updated process category sequence order from 15 to 17
--		because of the new steps that were added.
-- =============================================
CREATE PROCEDURE [dbo].[usp_DeleteAllExpensesAndAssocoationsAndResetStatus]
	@FiscalYear int = 2018, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   DECLARE @TSQL varchar(MAX) = ''

   SELECT @TSQL = '
   TRUNCATE TABLE [dbo].[Associations]

   TRUNCATE TABLE [dbo].[AllExpenses]

   UPDATE [dbo].[ProcessStatus]
   SET IsCompleted = 0
   WHERE Id IN (
	  select Id from  [dbo].[ProcessStatus]
	  WHERE CategoryID IN (
		  select Id from [dbo].[ProcessCategory]
		  WHERE SequenceOrder >= 17
	  )
   )

   UPDATE [dbo].[ProcessCategory]
   SET IsCompleted = 0 
   WHERE SequenceOrder >= 17
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END