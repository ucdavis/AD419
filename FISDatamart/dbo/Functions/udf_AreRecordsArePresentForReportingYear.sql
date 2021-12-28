-- =============================================
-- Author:		Ken Taylor
-- Create date: August 19,2021
-- Description:	Returns 1 (true) if any records for ReportingYear 
--		provided have been loaded.
-- Usage:
/*

USE [FISDataMart]
GO

DECLARE @ReportingYear int = 2022

SELECT [dbo].[udf_AreRecordsArePresentForReportingYear](@ReportingYear) AS AreRecordsLoaded
GO

*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION udf_AreRecordsArePresentForReportingYear 
(
	-- Add the parameters for the function here
	@ReportingYear int = NULL
)
RETURNS bit
AS
BEGIN
	--DECLARE @ReportingYear int = 2021 --(Uncomment for testing)
	-- Declare the return variable here
	DECLARE @Result bit

	IF @ReportingYear IS NULL 
		SELECT @ReportingYear = (SELECT FiscalYear FROM [CAES-DONBOT].[AD419].[dbo].[CurrentFiscalYear])
	--PRINT @ReportingYear

	-- Add the T-SQL statements to compute the return value here
	SELECT @Result = COALESCE( 
		(SELECT TOP (1) ReportingYear 
		FROM AnotherLaborTransactions
		WHERE ReportingYear = @ReportingYear)
	,0)
		
	--PRINT '[' + CONVERT(varchar(10),@Result) + ']'

	-- Return the result of the function
	RETURN @Result

END