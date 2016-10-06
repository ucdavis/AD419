-- =============================================
-- Author:		Ken Taylor
-- Create date: September 22, 2016
-- Description:	Return the appropriate segment to include in a where clause.
-- Usage:
/*
	SELECT dbo.udf_ReturnFYWhereClauseFiltering(DEFAULT, DEFAULT)
*/
-- Modifications:
-- =============================================
CREATE FUNCTION udf_ReturnFYWhereClauseFiltering
(
	-- Add the parameters for the function here
	@FiscalYear int = 2015,
	@UseStateFiscalYear bit = 0
)
RETURNS varchar(500)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @WhereClauseSegment varchar(500) = ''

	-- Add the T-SQL statements to compute the return value here
	IF @UseStateFiscalYear = 1
		SELECT @WhereClauseSegment = 'e.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + '
'	ELSE
		SELECT @WhereClauseSegment = '((e.FiscalYear = ' + CONVERT(varchar(4), @FiscalYear) + ' AND e.FiscalPeriod BETWEEN ''04'' AND ''13'') OR 
		 (e.FiscalYear = @' + CONVERT(varchar(4), @FiscalYear + 1) + ' AND e.FiscalPeriod BETWEEN ''01'' AND ''03''))
'

	-- Return the result of the function
	RETURN @WhereClauseSegment

END