
/*

	USE FISDataMart
	GO

	DECLARE @IsDebug bit = 0

	DECLARE @Return_value int, @Return_value2 int;
	EXEC usp_testReturnOutput2 @IsDebug = @IsDebug, @OutValue = @return_value OUTPUT, @SecondOutValue = @return_value2 OUTPUT

	IF @IsDebug = 0
		SELECT @Return_value AS ReturnedOutValue_FromSproc, @return_value2 AS RetuenedOutValue2_FromSproc

*/
-- =============================================
-- Author:		Ken Taylor
-- Create date: August 23, 2021
-- Description:	Test to determine how to return output value from sproc.
-- =============================================
CREATE PROCEDURE usp_testReturnOutput2
	-- Add the parameters for the stored procedure here
	@IsDebug bit = 1,
	@OutValue int OUTPUT,
	@SecondOutValue int OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @TSQL nvarchar(MAX) = ''

	SELECT @TSQL = '
	-- Set the return value here:
	SELECT @OutValueOut = 8, @SecondOutValueOut = 3
'

	IF @IsDebug = 1
		BEGIN
			SELECT @TSQL = '
	DECLARE @OutValueOut int,  @SecondOutValueOut int  -- have to add extra DECLARE if printing out SQL since it won''t have been defined 
' + @TSQL + '
	SELECT ''OutValueOut: '' =  @OutValueOut, ''SecondOutValueOut: '' = @SecondOutValueOut
	-- Add an extra line to print it out here, since it is not being returned 
	-- to the calling sproc.
'
			PRINT @TSQL
		END
	ELSE
		BEGIN
			DECLARE @Params nvarchar(100) = N'@OutValueOut int output, @SecondOutValueOut int OUTPUT' -- Same param name(s) as used in underlying sp
			EXEC sp_executesql @TSQL, @Params, @OutValueOut = @OutValue output, @SecondOutValueOut = @SecondOutValue output -- LH side matches param; 
			--															RH side is same name as calling sp return param
			SELECT @OutValue AS OutValue, @SecondOutValue AS SecondOutValue  -- check for valid return param
			SELECT 'TestOutput: ' = @OutValue, 'TestOutput2: ' = @SecondOutValue  -- select return param 
			RETURN -- Not required
		END

END