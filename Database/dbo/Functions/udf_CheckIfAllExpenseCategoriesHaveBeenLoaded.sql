-- =============================================
-- Author:		Ken Taylor
-- Create date: August 20, 2016
-- Description:	Check if all categories of expenses have been loaded
-- Usage:
/*
	SELECT dbo.udf_CheckIfAllExpenseCategoriesHaveBeenLoaded() AS AllExpenseCategoriesHaveBeenLoaded
*/
-- Modifications:
-- =============================================
CREATE FUNCTION udf_CheckIfAllExpenseCategoriesHaveBeenLoaded 
()
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result bit = 1
	DECLARE @FISCount int = 0, @PPSCount int = 0, @204Count int = 0, @20xCount int = 0, @CESCount int = 0,
	@FieldStationExpenseCount int = 0

	SELECT @FISCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'FIS'
		)

	SELECT @PPSCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'PPS'
		)

	SELECT @204Count = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '204'
		)

	SELECT @20xCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '20x'
		)

	SELECT @CESCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = 'CES'
		)

	SELECT @FieldStationExpenseCount = (
			SELECT COUNT(*) FROM AllExpenses WHERE DataSource = '22f'
		)

	IF @FISCount = 0 OR @PPSCount = 0 OR @204Count = 0 OR @20xCount = 0 Or @CESCount = 0 OR @FieldStationExpenseCount = 0
	BEGIN
		RETURN 0
	END


	RETURN @Result

END