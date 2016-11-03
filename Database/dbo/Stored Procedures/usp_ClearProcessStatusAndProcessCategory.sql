-- =============================================
-- Author:		Ken Taylor
-- Create date: September 7, 2016
-- Description:	Reset the ProcessStatus and ProcessCategory 
-- IsCompleted flags to false so we can restart the process 
-- the beginning.
--
-- Usage:
/*
	EXEC usp_ClearProcessStatusAndProcessCategory @IsDebug = 1 --*

-- *Note the the 2 parameters are just place holders and need not be provided.
*/
-- Modifications:
--	2016-11-02 by kjt: Modified to set step 0 back to done as this is handled by 
--	someone on the tech team once per reporting period and doesn't need to be repeated.
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClearProcessStatusAndProcessCategory] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2015, 
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   DECLARE @TSQL varchar(MAX) = ''

   SELECT @TSQL = '
   UPDATE [dbo].[ProcessStatus]
   SET IsCompleted = 0

   UPDATE [dbo].[ProcessCategory]
   SET IsCompleted = 0

   UPDATE [dbo].[ProcessCategory]
   SET IsCompleted = 1
   WHERE SequenceOrder = 0
'

	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END