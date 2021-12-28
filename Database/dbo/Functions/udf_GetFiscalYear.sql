-- =============================================
-- Author:		Ken Taylor
-- Create date: January 10, 2019
-- Description:	Return the current fiscal year
-- Usage:
/*
	USE [AD419]
	GO

	SELECT [dbo].[udf_GetFiscalYear] () AS FiscalYear
	GO
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_GetFiscalYear 
()
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @FiscalYear int

	-- Add the T-SQL statements to compute the return value here
	SELECT @FiscalYear = (SELECT FiscalYear FROM dbo.CurrentFiscalYear)

	-- Return the result of the function
	RETURN @FiscalYear

END