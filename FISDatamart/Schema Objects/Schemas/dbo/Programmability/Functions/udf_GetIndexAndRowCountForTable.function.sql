-- =============================================
-- Author:		Ken Taylor
-- Create date: April 6, 2011
-- Description:	Returns a list of indexes, and number of rows for 
-- the table name
-- =============================================
CREATE FUNCTION [dbo].[udf_GetIndexAndRowCountForTable]
(
	-- Add the parameters for the function here
	@TableName varchar(255)
)
RETURNS 
@Indexes TABLE 
(
	-- Add the column definitions for the TABLE variable here
	Name varchar(255), 
	Partition_Number int,
	index_id int,
	[type] int,
	type_desc varchar (255),
	[rows] bigint
)
AS
BEGIN
	
	INSERT INTO @Indexes
		SELECT name Name, p.partition_number [Partition Number], i.index_id [Index ID], i.type [Index Type], i.type_desc [Index Type Desc], p.rows [Rows]
		FROM sys.partitions p
		left outer JOIN sys.indexes i ON p.object_id = i.object_id and p.index_id = i.index_id
		WHERE i.OBJECT_ID = OBJECT_ID(@TableName) 
			AND p.partition_number IN (SELECT 
		p.partition_number 
		FROM sys.partitions p
		WHERE p.OBJECT_ID = OBJECT_ID(@TableName) 
		group by p.partition_number)
		order by p.partition_number, p.index_id DESC

	-- Fill the table variable with the rows for your result set
	RETURN 
	
END
