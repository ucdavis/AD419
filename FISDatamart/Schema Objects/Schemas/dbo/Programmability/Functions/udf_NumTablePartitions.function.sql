-- =============================================
-- Author:		Ken Taylor
-- Create date: April 11, 2011
-- Description:	Return the number of table partitions for the table name provided.
-- Usage: 
--		select dbo.udf_NumTablePartitions(<table_name>)
-- Example: 
--		select dbo.udf_NumTablePartitions('TransMain')
-- =============================================
CREATE FUNCTION [dbo].[udf_NumTablePartitions] 
(
	-- Add the parameters for the function here
	@TableName varchar(255)
)
RETURNS smallint
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ReturnVal smallint

	-- Add the T-SQL statements to compute the return value here
	SELECT @ReturnVal = (
		select distinct count(*) 
		from (
			SELECT 
				p.partition_number 
			FROM sys.partitions p
			WHERE p.OBJECT_ID = OBJECT_ID(@TableName) 
			GROUP BY p.partition_number
		) t1
	)
	
	RETURN @ReturnVal

END
