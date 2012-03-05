CREATE FUNCTION [dbo].[SplitVarcharValues]
(
	@ItemList varchar(500)
)
RETURNS 
@ParsedList table
(
	Item varchar(100)
)
AS
BEGIN
	DECLARE @Item varchar(100), @Pos int

	SET @ItemList = LTRIM(RTRIM(@ItemList))+ ','
	SET @Pos = CHARINDEX(',', @ItemList, 1)

	IF REPLACE(@ItemList, ',', '') <> ''
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
			SET @Pos = CHARINDEX(',', @ItemList, 1)

		END
	END	
	RETURN
END
