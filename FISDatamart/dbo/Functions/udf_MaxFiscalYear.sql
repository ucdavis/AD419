-- =============================================
-- Author:		Ken Taylor
-- Create date: January 23, 2019
-- Description:	Return the max, i.e. current, fiscal year from the Accounts table
-- Usage:
/*
	USE [FISDataMart]
	GO

	SELECT [dbo].[udf_MaxFiscalYear] () AS FiscalYear
	GO
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION [dbo].[udf_MaxFiscalYear] 
()
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @FiscalYear int

	-- Add the T-SQL statements to compute the return value here
	SELECT @FiscalYear = (
		SELECT MAX(Year) 
		FROM dbo.Accounts
		WHERE Year != 9999)

	-- Return the result of the function
	RETURN @FiscalYear

END