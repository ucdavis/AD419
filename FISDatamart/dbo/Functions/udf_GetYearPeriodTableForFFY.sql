-- =============================================
-- Author:		Ken Taylor
-- Create date: August 19, 2021
-- Description:	Returns a list of FiscalYears and their associated financial 
--	periods for the Federal FiscalYear provided.
-- Usage:
/*

USE [FISDataMart]
GO
DECLARE @FiscalYear int = 2021

SELECT * FROM [dbo].[udf_GetYearPeriodTableForFFY](@FiscalYear)

*/
-- Modifications
--
-- =============================================
CREATE FUNCTION udf_GetYearPeriodTableForFFY 
(
	-- Add the parameters for the function here
	@FiscalYear int
)
RETURNS 
@YearPeriodTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	FiscalYear int, 
	Period int
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	DECLARE @NextFiscalYear int = @FiscalYear + 1

	INSERT INTO @YearPeriodTable(FiscalYear, Period)
	VALUES 
		(@FiscalYear, 4),
		(@FiscalYear,5),
		(@FiscalYear,6),
		(@FiscalYear,7),
		(@FiscalYear,8),
		(@FiscalYear,9),
		(@FiscalYear,10), 
		(@FiscalYear,11), 
		(@FiscalYear,12), 
		(@FiscalYear,13),
		(@NextFiscalYear,1), 
		(@NextFiscalYear,2), 
		(@NextFiscalYear,3)
	
	RETURN 
END