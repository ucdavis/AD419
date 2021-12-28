
-- =============================================
-- Author:		Ken Taylor
-- Create date: December 20, 2019
-- Description:	Resets IsCompleted flags in the ProcessCategory and ProcessStatus tables
--	so that DataHelper Status' is returned to Step 29: Post-Processing.  That way
--	Shannon may re-run the final reports if Shannon or the departments have needed to
--	re-associate any expenses that may have been associated incorrectly.
--	  
-- Usage:
/*
	USE [AD419]
	GO

	EXEC usp_ResetStatusBackToPostProcessiongReview @FiscalYear = 2019, @IsDebug = 1
*/
--
-- Modifications:
--
CREATE PROCEDURE [dbo].[usp_ResetStatusBackToPostProcessiongReview] 
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2019,
	@IsDebug bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @TSQL varchar(MAX) = ''

	SELECT @TSQL = '
UPDATE ProcessStatus
SET IsCompleted = 0 
WHERE CategoryID IN (
	SELECT Id
	FROM ProcessCategory
	WHERE SequenceOrder > = 29
)

UPDATE ProcessCategory
SET IsCompleted = 0
WHERE SequenceOrder > = 29	
'

	IF @IsDebug = 1
		PRINT @TSQL	
	ELSE
		EXEC(@TSQL)

END