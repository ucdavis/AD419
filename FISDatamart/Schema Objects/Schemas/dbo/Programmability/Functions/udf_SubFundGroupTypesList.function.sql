-- =============================================
-- Author:		Ken Taylor
-- Create date: 2010-09-02
-- Description:	udf to allow a view to be used
-- to return a list of sub fund group types.
-- =============================================
CREATE FUNCTION [dbo].[udf_SubFundGroupTypesList] 
(
	-- Add the parameters for the function here
	@AddWildcard bit = 0
)
RETURNS 
@MyTable TABLE 
(
	-- Add the column definitions for the TABLE variable here
	SubFundGroupTypeValue varchar(2), 
	SubFundGroupTypeNameLabel varchar(45)
)
AS
BEGIN
	-- Fill the table variable with the rows for your result set
	
	If @AddWildcard = 1
		BEGIN
			Insert into @MyTable (
			SubFundGroupTypeValue,
			SubFundGroupTypeNameLabel
			) VALUES ('%', '%')
		END
		
	INSERT INTO @MyTable (
		SubFundGroupTypeValue,
		SubFundGroupTypeNameLabel
		)
	SELECT 
		SubFundGroupTypes.SubFundGroupType
		,(SubFundGroupTypes.SubFundGroupType + ' - ' + SubFundGroupTypes.SubFundGroupTypeName)
	FROM
		FISDataMart.dbo.SubFundGroupTypes
	ORDER BY 
		SubFundGroupTypes.SubFundGroupType
	
	RETURN 
END
