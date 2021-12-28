-- =============================================
-- Author:		Ken Taylor
-- Create date: February 8, 2011
-- Description:	Insert any missing records from TransactionLogV
-- Notes: Run this script after updating the FISDataMart.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateTransLog] 
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0 --Set to 1 to not execute, but print SQL only. 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

	-- Insert statements for procedure here
	DECLARE @TSQL varchar(MAX) = '
	DELETE FROM TransLog WHERE TransSourceTableCode = ''P''

	INSERT INTO TransLog
	SELECT * FROM TransactionLogV
	WHERE PKTrans IN
	(
		SELECT PKTrans FROM TransactionLogV
		EXCEPT
		SELECT PKTrans FROM TransLog
	)
	'
	IF @IsDebug = 1
		PRINT @TSQL
	ELSE
		EXEC(@TSQL)
END