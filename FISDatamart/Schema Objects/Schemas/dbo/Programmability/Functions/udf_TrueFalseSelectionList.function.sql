-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-July-07
-- Description:	Return a true/false; 0/1 table for easy use in a selection list
-- =============================================
CREATE FUNCTION [dbo].[udf_TrueFalseSelectionList] 
(
	-- Add the parameters for the function here
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	bool_name varchar(10), 
    YN_label varchar(5),
	bool_value bit
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	Insert into @MyTable values ('true', 'Y', 1),('false', 'N', 0)
	RETURN 
END
