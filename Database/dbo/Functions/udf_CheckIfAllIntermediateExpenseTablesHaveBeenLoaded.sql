-- =============================================
-- Author:		Ken Taylor
-- Create date: August 21, 2016
-- Description:	Check if all intermediate expense tables have been loaded
-- Usage:
/*
	SELECT dbo.udf_CheckIfAllIntermediateExpenseTablesHaveBeenLoaded() AS AllIntermediateExpenseTablesHaveBeenLoaded
*/
-- Modifications:
--
-- =============================================
CREATE FUNCTION [dbo].[udf_CheckIfAllIntermediateExpenseTablesHaveBeenLoaded] 
()
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result bit = 1
	DECLARE @Non204FisCount int = 0, @Non204PpsCount int = 0, @204FisCount int = 0, @204PpsCount int = 0
	
	SELECT @Non204FisCount = (
			SELECT COUNT(*) FROM FIS_ExpensesForNon204Projects
		)

	SELECT @Non204PpsCount = (
			SELECT COUNT(*) FROM PPS_ExpensesForNon204Projects
		)

	SELECT @204FisCount = (
			SELECT COUNT(*) FROM FIS_ExpensesFor204Projects
		)

	SELECT @204PpsCount = (
			SELECT COUNT(*) FROM PPS_ExpensesFor204Projects
		)

	IF @Non204FisCount = 0 OR @Non204PpsCount = 0 OR @204FisCount = 0 OR @204PpsCount = 0
	BEGIN
		RETURN 0
	END

	RETURN @Result

END