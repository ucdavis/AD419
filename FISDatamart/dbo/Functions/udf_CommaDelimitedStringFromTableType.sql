-- =============================================
-- Author:		Ken Taylor
-- Create date: June 14, 2018
-- Description:	Build a comma-delimited string to be used within a dynamic
--	SQL statement given a query parameter table type containing the list of
--	values to include in the comma-delimited string.
-- Usage:
/*
	DECLARE @QueryParameterTable AS QueryParameterTableType;
	INSERT INTO @QueryParameterTable
	SELECT DOS_Code FROM DosCodes
	SELECT dbo.udf_CommaDelimitedStringFromTableType(@QueryParameterTable, 2)

*/
-- Note that the values will be double quoted by default for use in a 
-- non-dynamic Oracle pass-thru OPENQUERY.
-- =============================================
CREATE FUNCTION [dbo].[udf_CommaDelimitedStringFromTableType] 
(
	-- Add the parameters for the function here
	@Values QueryParameterTableType READONLY,
	@NumQuotes int = 2
)
RETURNS varchar(MAX)
AS
BEGIN
	
	
	-- Declare the return variable here
	DECLARE @Result varchar(MAX) = ''
	DECLARE @DelimitedParameters varchar(MAX) = ''
	DECLARE @temp varchar(20) = '';
	DECLARE @SingleQuote varchar(4) = ''''
	DECLARE @TextQualifier varchar(10) = ''
	IF @NumQuotes != 0
		SELECT @TextQualifier = REPLICATE(@SingleQuote, @NumQuotes)

	DECLARE MyCursor CURSOR FOR SELECT Column1 FROM @Values FOR READ ONLY
	OPEN MyCursor

	FETCH NEXT FROM MyCursor INTO @temp
	-- Build the quotes parameters list:
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @DelimitedParameters +=  @TextQualifier + @temp + @TextQualifier
		FETCH NEXT FROM MyCursor INTO @temp
    
    	IF @@FETCH_STATUS = 0
    		SELECT @DelimitedParameters += ', ' 
	END

	CLOSE MyCursor
	DEALLOCATE MyCursor

	-- Return the result of the function
	SELECT @Result = @DelimitedParameters
	RETURN @Result

END