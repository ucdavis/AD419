-- =============================================
-- Author:		Ken Taylor
-- Create date: July 22, 2021
-- Description:	Given a federal fiscal year, return the return the 
-- corresponding number of hours, i.e. 2088 or 2096 for the fiscal year.
-- Notes: This number is used in for dividing the number of total hours
--		worked to determine the FTE, i.e., totalHours/2088 or 
--		totalHours/2096 (for leap years).  Creating a table holding this
--		value seemed unnecessary, when a simple calculation would do accomplish
--		the same task.
-- Usage:
/*

	USE [FISDataMart]
	GO

	DECLARE @FiscalYear int = 2021

	SELECT dbo.udf_GetHoursInFiscalYear(@FiscalYear) HoursInFFY
	GO

*/
--Modifications:
--
-- =============================================
CREATE FUNCTION udf_GetHoursInFiscalYear 
(
	-- Add the parameters for the function here
	@FiscalYear int
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Add the T-SQL statements to compute the return value here
	SELECT @Result = (CASE WHEN @FiscalYear % 4 = 0  THEN 2096 ELSE 2088 END)

	-- Return the result of the function
	RETURN @Result

END