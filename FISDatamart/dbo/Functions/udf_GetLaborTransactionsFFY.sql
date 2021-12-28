
-- =============================================
-- Author:		Ken Taylor
-- Create date: September 24, 2020
-- Description:	Return a list of federal fiscal years available in the Labor Transactions 
--	table for running the Animal Health Reports.
--
-- Usage:
/*
	USE [FISDataMart]
	GO

	SELECT * FROM udf_GetLaborTransactionsFFY()

*/
--
-- Modifications:
--	2021-07-16 by kjt: Revised to source AnotherLaborTransactions 
--	as now contains records for all employees.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_GetLaborTransactionsFFY] 
(
)
RETURNS 
@Table_Var TABLE 
(
	-- Add the column definitions for the TABLE variable here
	FiscalYear int
)
AS
BEGIN

	INSERT INTO @Table_Var
	SELECT Distinct ReportingYear
	FROM [dbo].[AnotherLaborTransactions]
	ORDER BY 1
	
	RETURN 
END