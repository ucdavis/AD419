
/*

	USE FISDataMart
	GO

	DECLARE @IsDebug bit = 0

	DECLARE @Return_value int;
	EXEC usp_testReturnOutput @IsDebug = @IsDebug, @OutValue = @return_value OUTPUT

	IF @IsDebug = 0
		SELECT @Return_value AS ReturnedOutValue

*/
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 23, 2021
-- Description:	Test to determine how to return output value from sproc.
-- =============================================
CREATE PROCEDURE usp_testReturnOutput
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 1,
	@OutValue int OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL nvarchar(MAX) = ''

	SELECT @TSQL = '
	-- Set the return value here:
	SELECT @OutValueOut = 8
'

	IF @IsDebug = 1
		BEGIN
			SELECT @TSQL = '
	DECLARE @OutValueOut int  -- have to add extra DECLARE if printing out SQL since it won''t have been defined 
' + @TSQL + '
	SELECT ''OutValueOut: '' =  @OutValueOut  -- Add an extra line to print it out here, since it is not being returned 
	-- to the calling sproc.
'
			PRINT @TSQL
		END
	ELSE
		BEGIN
			DECLARE @Params nvarchar(100) = N'@OutValueOut int output' -- Same param name as used in underlying sp
			EXEC sp_executesql @TSQL, @Params, @OutValueOut = @OutValue output -- LH side matches param; 
			--															RH side is same name as calling sp return param
			SELECT @OutValue AS OutValue  -- check for valid return param
			SELECT 'TestOutput: ' = @OutValue  -- select return param 
			RETURN -- Not required
		END

END