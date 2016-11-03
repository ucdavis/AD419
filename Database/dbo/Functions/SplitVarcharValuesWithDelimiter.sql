
/*
Created by: Ken Taylor
Created: 2016-07-29
Description: Splits a string by delimiter, and returns the split-out items in a table,
	similar to C#'s split command.
Usage:

	SELECT * FROM [dbo].[SplitVarcharValuesWithDelimiter] ('Taylor, Ken; Knoll, John; Kirkland, Scott', ';')

Sample Results:
	Item
	Taylor, Ken
	Knoll, John
	Kirkland, Scott

Modifications:
	2016-08-15 by kjt: Added comment header. 
*/
CREATE FUNCTION [dbo].[SplitVarcharValuesWithDelimiter]
(
	@ItemList varchar(500),
	@Delimiter varchar(1) = ','
)
RETURNS 
@ParsedList table
(
	Item varchar(100)
)
AS
BEGIN
	DECLARE @Item varchar(100), @Pos int

	SET @ItemList = LTRIM(RTRIM(@ItemList))+ @Delimiter
	SET @Pos = CHARINDEX(@Delimiter, @ItemList, 1)

	IF REPLACE(@ItemList, @Delimiter, '') <> ''
	BEGIN
		WHILE @Pos > 0
		BEGIN
			SET @Item = LTRIM(RTRIM(LEFT(@ItemList, @Pos - 1)))
			IF @Item <> ''
			BEGIN
				INSERT INTO @ParsedList (Item) 
				VALUES (@Item) --Use Appropriate conversion
			END
			SET @ItemList = RIGHT(@ItemList, LEN(@ItemList) - @Pos)
			SET @Pos = CHARINDEX(@Delimiter, @ItemList, 1)

		END
	END	
	RETURN
END