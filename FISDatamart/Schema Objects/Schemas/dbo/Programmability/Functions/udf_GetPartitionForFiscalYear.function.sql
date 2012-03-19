-- =============================================
-- Author:		Ken Taylor
-- Create date: March 9, 2011
-- Description:	Given a FiscalYear, return the corresponding table partition number
--
/*
This assumes that the PARTITION FUNCTION was created as follows:
 
CREATE PARTITION FUNCTION MyPartitionRange (int) 
AS RANGE LEFT FOR VALUES (1,2,3) 
*/
-- =============================================
CREATE FUNCTION [dbo].[udf_GetPartitionForFiscalYear] 
(
	-- Add the parameters for the function here
	@FiscalYear int
)
RETURNS int
AS
BEGIN
DECLARE @NumFiscalYearsToRetain int = 4

	-- Declare the return variable here
	DECLARE @PartitionNumber int

	-- Add the T-SQL statements to compute the return value here
	--(Year % (Year / 4)  +1)
	SELECT @PartitionNumber = (@FiscalYear % (@FiscalYear / @NumFiscalYearsToRetain)  +1)

	-- Return the result of the function
	RETURN @PartitionNumber

END

--print  [dbo].[udf_GetPartitionForFiscalYear] (2011)
