
-- =============================================
-- Author:		Ken Taylor
-- Create date: September 24, 2020
-- Description:	Return a distinct list of Employee Names based on the 
--	employee names present in the labor transactions table having the 
--	most recent pay period end date.
--
-- Usage:
/*

	SELECT EmployeeId, EmployeeName  FROM udf_EmployeeNames(2020)
	ORDER BY EmployeeName

*/
--
-- Modifications:
--	2021-06-15 by kjt: Revised to use FISDataMart's copy of AnotherLaborTransactions as
--		this table will be routinely updated.
--
-- =============================================
CREATE FUNCTION [dbo].[udf_EmployeeNames] 
(
	@FiscalYear int = 2019
)
RETURNS 
@Table_Var TABLE 
(
	-- Add the column definitions for the TABLE variable here
	EmployeeId varchar(9), 
	EmployeeName varchar(250)
)
AS
BEGIN
	INSERT INTO @Table_Var
	SELECT EmployeeId, EmployeeName 
	FROM
	(
		SELECT Distinct ROW_NUMBER() OVER (PARTITION BY EMPLOYEEID ORDER BY PayPeriodEndDate DESC) AS Id, EmployeeID, EmployeeName
		FROM AnotherLaborTransactions t1
		WHERE EmployeeName IS NOT NULL AND 
			ReportingYear = @FiscalYear
	) t1
	WHERE Id = 1
	
	RETURN 
END