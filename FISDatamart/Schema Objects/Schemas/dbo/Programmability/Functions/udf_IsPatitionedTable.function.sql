-- =============================================
-- Author:		Ken Taylor
-- Create date: April 11, 2011
-- Description:	Return 1 if a table has multiple partitions or 0 otherwise.
-- Usage: 
--		select  dbo.udf_IsPatitionedTable(<table_name>)
-- Example: 
--		select dbo.udf_IsPatitionedTable('TransMain')
-- =============================================
CREATE FUNCTION [dbo].[udf_IsPatitionedTable] 
(
	-- Add the parameters for the function here
	@TableName varchar(255)
)
RETURNS bit
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ReturnVal bit = 0

	-- Add the T-SQL statements to compute the return value here
	IF (select dbo.udf_NumTablePartitions(@TableName)) > 1 SELECT @ReturnVal = 1

	RETURN @ReturnVal

END
