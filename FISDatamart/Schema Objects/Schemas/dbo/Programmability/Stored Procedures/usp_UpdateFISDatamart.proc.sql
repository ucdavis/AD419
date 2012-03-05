-- =============================================
-- Author:		Ken Taylor
-- Create date: 2011-04-19
-- Description:	Calls usp_LoadFISDatamart with @TruncateTables bit set to false
-- in oder to update the FISDataMart non-manually loaded tables.
-- Modifications:
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateFISDatamart]
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 0, --Set this to 1 to print SQL only.
	@IsVerboseDebug bit = 0 --Set this to 1 to recurse into the inner sprocs themselves.
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

    -- Insert statements for procedure here
/*
	DECLARE @IsDebug bit = 0
*/	    
	IF @IsVerboseDebug = 1 SELECT @IsDebug = 1
	DECLARE @return_value int
	DECLARE @TSQL varchar(max) = ''
	SELECT @TSQL = '
	DECLARE @return_value int
	
	-- Update the database by calling usp_LoadFISDatamart with @TruncateTables set to false:
	
	EXEC	@return_value = [dbo].[usp_LoadFISDataMart] @TruncateTables = 0, @IsDebug = ' + CONVERT(char(1), @IsDebug) + ', @IsVerboseDebug = ' + CONVERT(char(1), @IsVerboseDebug) + '
    SELECT	''Return Value'' = @return_value
    '
    IF @IsVerboseDebug = 1
		BEGIN
			PRINT '/*' 
			PRINT @TSQL
			PRINT '*/'
			EXEC [dbo].[usp_LoadFISDataMart] @TruncateTables = 0, @IsDebug = @IsDebug , @IsVerboseDebug = @IsVerboseDebug
			SELECT @TSQL = ''
		END

	IF @IsDebug = 1
		BEGIN
			PRINT @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END
END
